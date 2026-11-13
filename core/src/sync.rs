//! Group sync. The host opens a 5-minute ticket; members connect, exchange what the
//! other is missing, and the host forwards new entries to everyone still connected.

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use anyhow::{anyhow, bail, Result};
use serde::Serialize;

use crate::crypto;
use crate::model::*;
use crate::net::{self, Chan, Msg};
use crate::store::Vault;
use crate::ticket::{self, TicketInner};

pub type SharedVault = Arc<Mutex<Vault>>;

/// A sync session serves at most this many devices at once.
pub const MAX_PEERS: usize = 32;

fn vv_vec(m: &BTreeMap<Pk, u64>) -> Vec<(Pk, u64)> {
    m.iter().map(|(k, v)| (*k, *v)).collect()
}

/// Ingest a batch into the vault. Returns the entries that were new.
fn ingest_batch(
    vault: &SharedVault,
    ws: &WsId,
    entries: Vec<Entry>,
) -> Result<(Vec<Entry>, BTreeMap<Pk, u64>)> {
    let mut v = vault.lock().unwrap();
    let log = v.ws_mut(ws)?;
    let mut fresh = Vec::new();
    for e in entries {
        match log.ingest(e.clone()) {
            Ok(true) => fresh.push(e),
            Ok(false) => {}
            Err(err) => eprintln!("nexvault: rejected entry: {err}"),
        }
    }
    let vv = log.vv();
    if !fresh.is_empty() {
        v.save()?;
    }
    Ok((fresh, vv))
}

fn mark_synced(vault: &SharedVault, ws: &WsId, peer: &Pk) {
    let mut v = vault.lock().unwrap();
    let local = v.data.local.entry(*ws).or_default();
    local.last_sync.insert(*peer, now_ms());
    // a restored device has its own later entries back now, so it may write again
    local.stale = false;
    let _ = v.save();
}

#[derive(Serialize, Clone, Debug)]
pub struct PeerStatus {
    pub pk: String,
    pub name: String,
    /// "syncing" | "done" | "left" | "rejected" | "removed"
    pub state: String,
    pub received: usize,
    pub sent: usize,
}

pub struct HostSession {
    pub ws: WsId,
    pub ticket: String,
    pub exp: u64,
    stop: AtomicBool,
    peers: Mutex<Vec<PeerStatus>>,
    chans: Mutex<Vec<(Pk, Chan)>>,
}

impl HostSession {
    pub fn peers(&self) -> Vec<PeerStatus> {
        self.peers.lock().unwrap().clone()
    }
    pub fn accepting(&self) -> bool {
        !self.stop.load(Ordering::SeqCst) && now_ms() < self.exp
    }
    pub fn stop(&self) {
        self.stop.store(true, Ordering::SeqCst);
        for (_, c) in self.chans.lock().unwrap().drain(..) {
            let _ = c.send(&Msg::Bye);
            c.shutdown();
        }
    }
    fn set_peer(&self, pk: &Pk, name: &str, f: impl FnOnce(&mut PeerStatus)) {
        let mut ps = self.peers.lock().unwrap();
        let key = hex::encode(pk);
        let idx = match ps.iter().position(|p| p.pk == key) {
            Some(i) => i,
            None => {
                ps.push(PeerStatus {
                    pk: key,
                    name: name.into(),
                    state: "syncing".into(),
                    received: 0,
                    sent: 0,
                });
                ps.len() - 1
            }
        };
        f(&mut ps[idx]);
    }
}

pub fn host(vault: SharedVault, ws: WsId, minutes: u64) -> Result<Arc<HostSession>> {
    let (me, st) = {
        let v = vault.lock().unwrap();
        (v.identity()?.clone(), v.state(&ws)?)
    };
    let _ = &st;
    let tk = vault.lock().unwrap().ticket_key(&ws)?;
    let (listener, port, addrs) = net::listen()?;
    let psk: [u8; 32] = crypto::random();
    let exp = now_ms() + minutes * 60_000;
    let inner = TicketInner {
        v: 1,
        host: me.sign_pk(),
        addrs,
        port,
        psk,
        exp,
    };
    let ticket = ticket::encode_ticket(&ws, &tk, &inner, &me.sign_sk);
    let sess = Arc::new(HostSession {
        ws,
        ticket,
        exp,
        stop: AtomicBool::new(false),
        peers: Mutex::new(vec![]),
        chans: Mutex::new(vec![]),
    });
    let s2 = sess.clone();
    thread::spawn(move || accept_loop(listener, vault, s2, me.dh_sk, psk));
    Ok(sess)
}

fn accept_loop(
    l: net::Listener,
    vault: SharedVault,
    sess: Arc<HostSession>,
    dh_sk: [u8; 32],
    psk: [u8; 32],
) {
    while sess.accepting() {
        match l.accept() {
            Ok((stream, _)) => {
                let _ = stream.set_nonblocking(false);
                let (v, s) = (vault.clone(), sess.clone());
                thread::spawn(move || {
                    if let Err(e) = serve_peer(stream, v, s, dh_sk, psk) {
                        eprintln!("nexvault host: peer ended: {e}");
                    }
                });
            }
            Err(_) => thread::sleep(Duration::from_millis(120)),
        }
    }
    // dropping the listener closes the port
}

fn serve_peer(
    stream: std::net::TcpStream,
    vault: SharedVault,
    sess: Arc<HostSession>,
    dh_sk: [u8; 32],
    psk: [u8; 32],
) -> Result<()> {
    let ws = sess.ws;
    let chan = match Chan::responder(stream, &dh_sk, &psk) {
        Ok(c) => c,
        Err(e) => {
            // wrong PSK or garbage: count it as a stranger
            sess.set_peer(&[0u8; 32], "?", |p| p.state = "rejected".into());
            return Err(e);
        }
    };
    let st = vault.lock().unwrap().state(&ws)?;
    // members, plus newcomers still collecting approvals (they need the approvals to arrive)
    let found = st
        .members
        .iter()
        .find(|m| m.dh_pk == chan.remote_static)
        .cloned()
        .or_else(|| st.pending_by_dh(&chan.remote_static).cloned());
    let Some(member) = found else {
        // a removed member still holds the ticket key; say who it was, refuse it
        match st.removed.iter().find(|m| m.dh_pk == chan.remote_static) {
            Some(m) => {
                sess.set_peer(&m.sign_pk, &m.name, |p| p.state = "removed".into());
                let _ = chan.send(&Msg::Error("removed".into()));
            }
            None => {
                sess.set_peer(&chan.remote_static, "?", |p| p.state = "rejected".into());
                let _ = chan.send(&Msg::Error("not a member".into()));
            }
        }
        chan.shutdown();
        return Ok(());
    };
    let pk = member.sign_pk;
    if sess.chans.lock().unwrap().len() >= MAX_PEERS {
        chan.shutdown();
        bail!("too many peers in this session");
    }
    sess.set_peer(&pk, &member.name, |p| p.state = "syncing".into());
    let their_vv: BTreeMap<Pk, u64> = match chan.recv()? {
        Some(Msg::Hello { ws: w, vv }) if w == ws => vv.into_iter().collect(),
        _ => return Err(anyhow!("expected hello")),
    };
    // Snapshot, reply and register atomically w.r.t. ingest: an entry ingested from another
    // peer is either in this snapshot or forwarded to us after we are registered (never lost,
    // and never delivered before our Hello).
    let n = {
        let v = vault.lock().unwrap();
        let log = v.ws(&ws)?;
        let missing = log.missing_for(&their_vv);
        let n = missing.len();
        chan.send(&Msg::Hello {
            ws,
            vv: vv_vec(&log.vv()),
        })?;
        chan.send(&Msg::Entries(missing))?;
        let mut chans = sess.chans.lock().unwrap();
        if let Some(i) = chans.iter().position(|(p, _)| p == &pk) {
            chans.remove(i).1.shutdown(); // same device reconnecting
        }
        chans.push((pk, chan.clone()));
        n
    };
    sess.set_peer(&pk, &member.name, |p| p.sent += n);

    loop {
        let msg = match chan.recv() {
            Ok(Some(m)) => m,
            Ok(None) => continue,
            Err(_) => break,
        };
        match msg {
            Msg::Entries(es) => {
                let got = es.len();
                let (fresh, vv) = ingest_batch(&vault, &ws, es)?;
                sess.set_peer(&pk, &member.name, |p| p.received += got);
                chan.send(&Msg::Ack { vv: vv_vec(&vv) })?;
                if !fresh.is_empty() {
                    // hub: forward to everyone else connected right now
                    let others: Vec<(Pk, Chan)> = sess
                        .chans
                        .lock()
                        .unwrap()
                        .iter()
                        .filter(|(p, _)| p != &pk)
                        .cloned()
                        .collect();
                    for (opk, oc) in others {
                        if oc.send(&Msg::Entries(fresh.clone())).is_ok() {
                            let name = st.member(&opk).map(|m| m.name.clone()).unwrap_or_default();
                            sess.set_peer(&opk, &name, |p| {
                                p.sent += fresh.len();
                                p.state = "syncing".into();
                            });
                        }
                    }
                }
            }
            Msg::Ack { vv } => {
                let theirs: BTreeMap<Pk, u64> = vv.into_iter().collect();
                let mine = vault.lock().unwrap().ws(&ws)?.vv();
                if theirs == mine {
                    sess.set_peer(&pk, &member.name, |p| p.state = "done".into());
                    mark_synced(&vault, &ws, &pk);
                }
                // Answer every Ack so a joiner that caught up through forwarded entries
                // learns it is in sync. Joiners never answer Acks, so this cannot loop.
                chan.send(&Msg::Ack { vv: vv_vec(&mine) })?;
            }
            Msg::Bye => break,
            _ => {}
        }
    }
    sess.set_peer(&pk, &member.name, |p| {
        if p.state != "done" {
            p.state = "left".into()
        }
    });
    sess.chans.lock().unwrap().retain(|(p, _)| p != &pk);
    Ok(())
}

#[derive(Serialize, Clone, Debug, Default)]
pub struct JoinStatus {
    /// "connecting" | "syncing" | "done" | "closed" | "error"
    pub state: String,
    pub ws: String,
    pub host: String,
    pub received: usize,
    pub sent: usize,
    pub error: Option<String>,
}

pub struct JoinSession {
    stop: AtomicBool,
    status: Mutex<JoinStatus>,
}

impl JoinSession {
    pub fn status(&self) -> JoinStatus {
        self.status.lock().unwrap().clone()
    }
    pub fn stop(&self) {
        self.stop.store(true, Ordering::SeqCst);
    }
    fn set(&self, f: impl FnOnce(&mut JoinStatus)) {
        f(&mut self.status.lock().unwrap());
    }
}

pub fn join(vault: SharedVault, ticket_str: &str) -> Result<Arc<JoinSession>> {
    let ws = ticket::ticket_ws(ticket_str)?;
    let (me, st) = {
        let v = vault.lock().unwrap();
        (
            v.identity()?.clone(),
            v.state(&ws)
                .map_err(|_| anyhow!("this sync code is for a workspace you are not in"))?,
        )
    };
    let tk = vault.lock().unwrap().ticket_key(&ws)?;
    let t = ticket::decode_ticket(ticket_str, &tk)?;
    let host = st
        .members
        .iter()
        .find(|m| m.sign_pk == t.host)
        .cloned()
        .ok_or_else(|| anyhow!("host is not a member"))?;
    let sess = Arc::new(JoinSession {
        stop: AtomicBool::new(false),
        status: Mutex::new(JoinStatus {
            state: "connecting".into(),
            ws: hex::encode(ws),
            host: host.name.clone(),
            ..Default::default()
        }),
    });
    let s2 = sess.clone();
    thread::spawn(move || {
        if let Err(e) = run_join(vault, s2.clone(), ws, me.dh_sk, host, t) {
            s2.set(|s| {
                if s.state != "done" && s.state != "closed" {
                    s.state = "error".into();
                    s.error = Some(e.to_string());
                }
            });
        }
    });
    Ok(sess)
}

fn run_join(
    vault: SharedVault,
    sess: Arc<JoinSession>,
    ws: WsId,
    dh_sk: [u8; 32],
    host: Member,
    t: TicketInner,
) -> Result<()> {
    let stream = net::connect_any(&t.addrs, t.port)?;
    let chan = Chan::initiator(stream, &dh_sk, &host.dh_pk, &t.psk)?;
    sess.set(|s| s.state = "syncing".into());
    let my_vv = vault.lock().unwrap().ws(&ws)?.vv();
    // a host that refuses us may close before Hello lands: still read its reason
    let sent = chan.send(&Msg::Hello {
        ws,
        vv: vv_vec(&my_vv),
    });
    let host_vv: BTreeMap<Pk, u64> = match chan.recv() {
        Ok(Some(Msg::Hello { vv, .. })) => vv.into_iter().collect(),
        Ok(Some(Msg::Error(e))) if e == "removed" => bail!("you were removed from this workspace"),
        Ok(Some(Msg::Error(_))) | Err(_) => bail!("the host refused this device"),
        other => {
            sent?;
            return Err(anyhow!("unexpected reply: {other:?}"));
        }
    };
    let missing = vault.lock().unwrap().ws(&ws)?.missing_for(&host_vv);
    let n = missing.len();
    chan.send(&Msg::Entries(missing))?;
    sess.set(|s| s.sent = n);
    chan.set_read_timeout(Some(Duration::from_millis(400)));
    loop {
        if sess.stop.load(Ordering::SeqCst) {
            let _ = chan.send(&Msg::Bye);
            chan.shutdown();
            sess.set(|s| s.state = "closed".into());
            return Ok(());
        }
        let msg = match chan.recv() {
            Ok(Some(m)) => m,
            Ok(None) => continue,
            Err(_) => {
                sess.set(|s| {
                    if s.state != "done" {
                        s.state = "closed".into()
                    }
                });
                return Ok(());
            }
        };
        match msg {
            Msg::Entries(es) => {
                let got = es.len();
                let (_, vv) = ingest_batch(&vault, &ws, es)?;
                sess.set(|s| s.received += got);
                chan.send(&Msg::Ack { vv: vv_vec(&vv) })?;
            }
            Msg::Ack { vv } => {
                let theirs: BTreeMap<Pk, u64> = vv.into_iter().collect();
                let mine = vault.lock().unwrap().ws(&ws)?.vv();
                if theirs == mine {
                    sess.set(|s| s.state = "done".into());
                    mark_synced(&vault, &ws, &host.sign_pk);
                }
            }
            Msg::Bye => {
                sess.set(|s| {
                    if s.state != "done" {
                        s.state = "closed".into()
                    }
                });
                return Ok(());
            }
            _ => {}
        }
    }
}
