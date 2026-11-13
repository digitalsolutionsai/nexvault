//! In-person workspace creation. The creator shows an invite QR; each member scans it,
//! both screens derive the same seal + 6-digit code from the Noise handshake, the joiner
//! must pick the code the creator reads aloud, then everyone co-signs the Genesis entry.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use anyhow::{anyhow, bail, Result};
use rand::seq::SliceRandom;
use serde::Serialize;

use crate::crypto;
use crate::model::*;
use crate::net::{self, Chan, Msg};
use crate::sync::SharedVault;
use crate::ticket::{self, Invite};

#[derive(Serialize, Clone, Debug)]
pub struct JoinerView {
    pub pk: String,
    pub name: String,
    pub code: String,
    pub seal: String,
    /// the joiner picked the right code on their screen
    pub verified: bool,
    /// the joiner picked a wrong code: possible interception, do not add
    pub failed: bool,
    /// creator ticked "add this person"
    pub accepted: bool,
}

struct Joiner {
    view: JoinerView,
    member: Member,
    chan: Chan,
}

pub struct CreatorSession {
    pub invite: String,
    pub ws_name: String,
    pub existing: Option<WsId>,
    stop: AtomicBool,
    joiners: Mutex<Vec<Joiner>>,
    /// "open" | "finishing" | "done" | "error"
    state: Mutex<(String, Option<String>, Option<WsId>)>,
}

#[derive(Serialize)]
pub struct CreatorStatus {
    pub state: String,
    pub error: Option<String>,
    pub ws: Option<String>,
    pub joiners: Vec<JoinerView>,
}

impl CreatorSession {
    pub fn status(&self) -> CreatorStatus {
        let (state, error, ws) = self.state.lock().unwrap().clone();
        CreatorStatus {
            state,
            error,
            ws: ws.map(hex::encode),
            joiners: self
                .joiners
                .lock()
                .unwrap()
                .iter()
                .map(|j| j.view.clone())
                .collect(),
        }
    }
    pub fn accept(&self, pk_hex: &str, ok: bool) -> Result<()> {
        let mut js = self.joiners.lock().unwrap();
        let j = js
            .iter_mut()
            .find(|j| j.view.pk == pk_hex)
            .ok_or_else(|| anyhow!("unknown person"))?;
        if ok && !j.view.verified {
            bail!("{} has not confirmed the code yet", j.view.name);
        }
        j.view.accepted = ok;
        Ok(())
    }
    pub fn cancel(&self) {
        self.stop.store(true, Ordering::SeqCst);
        for j in self.joiners.lock().unwrap().iter() {
            let _ = j.chan.send(&Msg::Error("cancelled by creator".into()));
            j.chan.shutdown();
        }
    }
}

/// `existing` = Some(ws) to invite newcomers into a workspace this device belongs to.
pub fn create(
    vault: SharedVault,
    ws_name: &str,
    existing: Option<WsId>,
) -> Result<Arc<CreatorSession>> {
    let me = vault.lock().unwrap().identity()?.clone();
    let ws_name = match existing {
        Some(ws) => {
            let st = vault.lock().unwrap().state(&ws)?;
            if !st.is_member(&me.sign_pk()) || !st.can_read() {
                bail!("only a member can invite");
            }
            st.name
        }
        None => ws_name.trim().to_string(),
    };
    if ws_name.is_empty() || ws_name.len() > MAX_NAME_LEN {
        bail!("invalid name");
    }
    let ws_name = ws_name.as_str();
    let (listener, port, addrs) = net::listen()?;
    let psk: [u8; 32] = crypto::random();
    let inv = Invite {
        v: 1,
        ws_name: ws_name.to_string(),
        ws: existing,
        creator: me.member(),
        addrs,
        port,
        psk,
        exp: now_ms() + 15 * 60_000,
    };
    let sess = Arc::new(CreatorSession {
        invite: ticket::encode_invite(&inv),
        ws_name: ws_name.to_string(),
        existing,
        stop: AtomicBool::new(false),
        joiners: Mutex::new(vec![]),
        state: Mutex::new(("open".into(), None, None)),
    });
    let s2 = sess.clone();
    let me_m = me.member();
    thread::spawn(move || creator_accept(listener, s2, me.dh_sk, me_m, psk, inv.exp));
    Ok(sess)
}

fn creator_accept(
    l: net::Listener,
    sess: Arc<CreatorSession>,
    dh_sk: [u8; 32],
    me: Member,
    psk: [u8; 32],
    exp: u64,
) {
    while !sess.stop.load(Ordering::SeqCst)
        && now_ms() < exp
        && sess.state.lock().unwrap().0 == "open"
    {
        match l.accept() {
            Ok((stream, _)) => {
                let _ = stream.set_nonblocking(false);
                let (s, m) = (sess.clone(), me.clone());
                thread::spawn(move || {
                    if let Err(e) = creator_serve(stream, s, dh_sk, m, psk) {
                        eprintln!("nexvault ceremony: {e}");
                    }
                });
            }
            Err(_) => thread::sleep(Duration::from_millis(120)),
        }
    }
}

fn creator_serve(
    stream: std::net::TcpStream,
    sess: Arc<CreatorSession>,
    dh_sk: [u8; 32],
    me: Member,
    psk: [u8; 32],
) -> Result<()> {
    let chan = Chan::responder(stream, &dh_sk, &psk)?;
    let member = match chan.recv()? {
        Some(Msg::Profile(m)) if m.dh_pk == chan.remote_static => m,
        _ => bail!("expected profile"),
    };
    let (code, seal) = crypto::sas(&chan.handshake_hash);
    {
        let mut js = sess.joiners.lock().unwrap();
        js.retain(|j| j.member.sign_pk != member.sign_pk);
        js.push(Joiner {
            view: JoinerView {
                pk: hex::encode(member.sign_pk),
                name: member.name.clone(),
                code,
                seal: hex::encode(seal),
                verified: false,
                failed: false,
                accepted: false,
            },
            member: member.clone(),
            chan: chan.clone(),
        });
    }
    chan.send(&Msg::Profile(me))?;
    match chan.recv()? {
        Some(Msg::Confirmed { ok }) => {
            let mut js = sess.joiners.lock().unwrap();
            if let Some(j) = js.iter_mut().find(|j| j.member.sign_pk == member.sign_pk) {
                j.view.verified = ok;
                j.view.failed = !ok;
            }
        }
        _ => bail!("joiner left before confirming"),
    }
    Ok(())
}

/// Build Genesis with the creator and every accepted joiner, collect co-signatures, store it.
pub fn finish(vault: SharedVault, sess: &CreatorSession) -> Result<WsId> {
    *sess.state.lock().unwrap() = ("finishing".into(), None, None);
    let r = (|| -> Result<WsId> {
        let me = vault.lock().unwrap().identity()?.clone();
        let joiners: Vec<(Member, Chan)> = sess
            .joiners
            .lock()
            .unwrap()
            .iter()
            .filter(|j| j.view.accepted && j.view.verified)
            .map(|j| (j.member.clone(), j.chan.clone()))
            .collect();
        if joiners.is_empty() {
            bail!("add at least one other member");
        }
        if let Some(ws) = sess.existing {
            return invite_existing(&vault, ws, &joiners);
        }
        let ws: WsId = crypto::random();
        let epoch0: [u8; 32] = crypto::random();
        let mut members = vec![me.member()];
        members.extend(joiners.iter().map(|(m, _)| m.clone()));
        let keys = members
            .iter()
            .map(|m| KeyWrap {
                epoch: 0,
                wrap: crypto::wrap_for(m, &epoch0, &epoch_ctx(&ws, 0)),
            })
            .collect();
        let body = Body {
            ws,
            author: me.sign_pk(),
            seq: 1,
            ts: now_ms(),
            op: Op::Genesis {
                name: sess.ws_name.clone(),
                members,
                keys,
            },
        };
        let mut entry = Entry::signed(&body, &me.sign_sk);
        for (m, c) in &joiners {
            c.send(&Msg::GenesisDraft {
                body: entry.body.clone(),
            })?;
            c.set_read_timeout(Some(Duration::from_secs(60)));
            match c.recv()? {
                Some(Msg::Cosign { sig }) if crypto::verify(&m.sign_pk, &entry.body, &sig) => {
                    entry.sigs.push(Sig { by: m.sign_pk, sig })
                }
                _ => bail!("{} did not co-sign", m.name),
            }
        }
        let mut log = WsLog {
            ws,
            entries: vec![],
        };
        log.ingest(entry.clone())?;
        {
            let mut v = vault.lock().unwrap();
            v.data.workspaces.push(log);
            let local = v.data.local.entry(ws).or_default();
            for (m, _) in &joiners {
                local.last_sync.insert(m.sign_pk, now_ms());
            }
            v.save()?;
        }
        for (_, c) in &joiners {
            let _ = c.send(&Msg::GenesisFinal(entry.clone()));
        }
        Ok(ws)
    })();
    sess.stop.store(true, Ordering::SeqCst);
    let mut st = sess.state.lock().unwrap();
    match &r {
        Ok(ws) => *st = ("done".into(), None, Some(*ws)),
        Err(e) => *st = ("error".into(), Some(e.to_string()), None),
    }
    r
}

/// Member add: record an Add proposal per newcomer (counts as the inviter's approval),
/// then hand each newcomer the log and the ticket key.
fn invite_existing(vault: &SharedVault, ws: WsId, joiners: &[(Member, Chan)]) -> Result<WsId> {
    let (entries, tk) = {
        let mut v = vault.lock().unwrap();
        for (m, _) in joiners {
            v.propose(&ws, Change::Add { member: m.clone() })?;
        }
        v.save()?;
        (v.ws(&ws)?.entries.clone(), v.ticket_key(&ws)?)
    };
    for (_, c) in joiners {
        c.send(&Msg::Bootstrap {
            entries: entries.clone(),
            ticket_key: tk,
        })?;
    }
    Ok(ws)
}

// ---------------------------------------------------------------- joiner side

#[derive(Serialize, Clone, Debug, Default)]
pub struct JoinCeremonyStatus {
    /// "connecting" | "verify" | "waiting" | "done" | "aborted" | "error"
    pub state: String,
    pub ws_name: String,
    pub creator: String,
    pub seal: String,
    /// three codes, one of which is right; the user picks the one the creator reads aloud
    pub choices: Vec<String>,
    pub ws: Option<String>,
    pub error: Option<String>,
}

pub struct JoinCeremony {
    status: Mutex<JoinCeremonyStatus>,
    code: Mutex<String>,
    pick: Mutex<Option<String>>,
}

impl JoinCeremony {
    pub fn status(&self) -> JoinCeremonyStatus {
        self.status.lock().unwrap().clone()
    }
    /// Returns whether the picked code was right.
    pub fn pick(&self, code: &str) -> bool {
        *self.pick.lock().unwrap() = Some(code.to_string());
        *self.code.lock().unwrap() == code
    }
    fn set(&self, f: impl FnOnce(&mut JoinCeremonyStatus)) {
        f(&mut self.status.lock().unwrap());
    }
}

pub fn join(vault: SharedVault, invite: &str) -> Result<Arc<JoinCeremony>> {
    let inv = ticket::decode_invite(invite)?;
    let sess = Arc::new(JoinCeremony {
        status: Mutex::new(JoinCeremonyStatus {
            state: "connecting".into(),
            ws_name: inv.ws_name.clone(),
            creator: inv.creator.name.clone(),
            ..Default::default()
        }),
        code: Mutex::new(String::new()),
        pick: Mutex::new(None),
    });
    let s2 = sess.clone();
    thread::spawn(move || {
        if let Err(e) = run_join(vault, s2.clone(), inv) {
            s2.set(|s| {
                if s.state != "aborted" {
                    s.state = "error".into();
                    s.error = Some(e.to_string());
                }
            });
        }
    });
    Ok(sess)
}

fn run_join(vault: SharedVault, sess: Arc<JoinCeremony>, inv: Invite) -> Result<()> {
    let me = vault.lock().unwrap().identity()?.clone();
    let stream = net::connect_any(&inv.addrs, inv.port)?;
    let chan = Chan::initiator(stream, &me.dh_sk, &inv.creator.dh_pk, &inv.psk)?;
    chan.send(&Msg::Profile(me.member()))?;
    match chan.recv()? {
        Some(Msg::Profile(_)) => {}
        _ => bail!("creator did not answer"),
    }
    let (code, seal) = crypto::sas(&chan.handshake_hash);
    let mut choices = crypto::sas_decoys(&code, &chan.handshake_hash);
    choices.push(code.clone());
    choices.shuffle(&mut rand::thread_rng());
    *sess.code.lock().unwrap() = code.clone();
    sess.set(|s| {
        s.state = "verify".into();
        s.seal = hex::encode(seal);
        s.choices = choices;
    });
    // wait for the user to pick
    let picked = loop {
        if let Some(p) = sess.pick.lock().unwrap().clone() {
            break p;
        }
        thread::sleep(Duration::from_millis(100));
    };
    let ok = picked == code;
    chan.send(&Msg::Confirmed { ok })?;
    if !ok {
        sess.set(|s| s.state = "aborted".into());
        chan.shutdown();
        return Ok(());
    }
    sess.set(|s| s.state = "waiting".into());
    chan.set_read_timeout(None);
    let body_bytes = match chan.recv()? {
        Some(Msg::GenesisDraft { body }) => body,
        Some(Msg::Bootstrap {
            entries,
            ticket_key,
        }) => return finish_bootstrap(&vault, &sess, &inv, entries, ticket_key),
        Some(Msg::Error(e)) => bail!(e),
        _ => bail!("expected the workspace charter"),
    };
    let body: Body = uncbor(&body_bytes)?;
    match &body.op {
        Op::Genesis { name, members, .. } => {
            if body.author != inv.creator.sign_pk || name != &inv.ws_name {
                bail!("charter does not match the invite");
            }
            if !members.iter().any(|m| m.sign_pk == me.sign_pk()) {
                bail!("charter does not include you");
            }
        }
        _ => bail!("not a charter"),
    }
    chan.send(&Msg::Cosign {
        sig: crypto::sign(&me.sign_sk, &body_bytes),
    })?;
    let entry = match chan.recv()? {
        Some(Msg::GenesisFinal(e)) if e.body == body_bytes => e,
        _ => bail!("did not receive the final charter"),
    };
    let mut log = WsLog {
        ws: body.ws,
        entries: vec![],
    };
    log.ingest(entry)?;
    {
        let mut v = vault.lock().unwrap();
        if v.data.workspaces.iter().any(|w| w.ws == body.ws) {
            bail!("workspace already exists");
        }
        v.data.workspaces.push(log);
        v.data
            .local
            .entry(body.ws)
            .or_default()
            .last_sync
            .insert(inv.creator.sign_pk, now_ms());
        v.save()?;
    }
    sess.set(|s| {
        s.state = "done".into();
        s.ws = Some(hex::encode(body.ws));
    });
    Ok(())
}

/// Newcomer side of a member add: store the log; keys arrive once every member approves.
fn finish_bootstrap(
    vault: &SharedVault,
    sess: &JoinCeremony,
    inv: &Invite,
    entries: Vec<Entry>,
    tk: [u8; 32],
) -> Result<()> {
    let ws = inv.ws.ok_or_else(|| anyhow!("unexpected workspace log"))?;
    let me = vault.lock().unwrap().identity()?.member();
    let mut log = WsLog {
        ws,
        entries: vec![],
    };
    for e in entries {
        log.ingest(e)?;
    }
    let st = log.fold(None);
    if st.name != inv.ws_name || !st.is_member(&inv.creator.sign_pk) {
        bail!("workspace does not match the invite");
    }
    if st
        .pending_member(&me.sign_pk)
        .is_none_or(|m| m.dh_pk != me.dh_pk)
    {
        bail!("the invite does not include you");
    }
    {
        let mut v = vault.lock().unwrap();
        if v.data.workspaces.iter().any(|w| w.ws == ws) {
            bail!("workspace already exists");
        }
        v.data.workspaces.push(log);
        let local = v.data.local.entry(ws).or_default();
        local.last_sync.insert(inv.creator.sign_pk, now_ms());
        local.pending_ticket_key = Some(tk);
        v.save()?;
    }
    sess.set(|s| {
        s.state = "done".into();
        s.ws = Some(hex::encode(ws));
    });
    Ok(())
}
