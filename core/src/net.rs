//! Noise IKpsk2 channel over TCP, message framing, local address discovery.

use std::io::{Read, Write};
use std::net::{IpAddr, SocketAddr, TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};
use socket2::{Domain, Socket, Type};

use crate::model::*;

pub const NOISE: &str = "Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s";
const MAX_FRAME: usize = 65535;
const CHUNK: usize = 60_000;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Msg {
    // sync
    Hello {
        ws: WsId,
        vv: Vec<(Pk, u64)>,
    },
    Entries(Vec<Entry>),
    Ack {
        vv: Vec<(Pk, u64)>,
    },
    Bye,
    // ceremony
    Profile(Member),
    Confirmed {
        ok: bool,
    },
    GenesisDraft {
        #[serde(with = "serde_bytes")]
        body: Vec<u8>,
    },
    Cosign {
        #[serde(with = "serde_bytes")]
        sig: Vec<u8>,
    },
    GenesisFinal(Entry),
    /// Member add: the workspace log so far, plus the ticket key so the newcomer can
    /// read sync codes while the other members approve.
    Bootstrap {
        entries: Vec<Entry>,
        #[serde(with = "serde_bytes")]
        ticket_key: [u8; 32],
    },
    Error(String),
}

fn write_frame(s: &mut TcpStream, b: &[u8]) -> Result<()> {
    if b.len() > MAX_FRAME {
        bail!("frame too large");
    }
    s.write_all(&(b.len() as u16).to_be_bytes())?;
    s.write_all(b)?;
    Ok(())
}

fn read_frame(s: &mut TcpStream) -> Result<Vec<u8>> {
    let mut l = [0u8; 2];
    s.read_exact(&mut l)?;
    let mut b = vec![0u8; u16::from_be_bytes(l) as usize];
    s.read_exact(&mut b)?;
    Ok(b)
}

/// One encrypted, mutually authenticated connection. Clone it to read and write from
/// different threads: the socket is duplicated, the Noise transport is shared.
#[derive(Clone)]
pub struct Chan {
    stream: Arc<Mutex<TcpStream>>,
    reader: Arc<Mutex<TcpStream>>,
    ts: Arc<Mutex<snow::TransportState>>,
    pub remote_static: Pk,
    pub handshake_hash: Vec<u8>,
}

impl Chan {
    pub fn initiator(
        mut s: TcpStream,
        my_dh_sk: &[u8; 32],
        remote_dh_pk: &Pk,
        psk: &[u8; 32],
    ) -> Result<Chan> {
        s.set_nodelay(true).ok();
        s.set_read_timeout(Some(Duration::from_secs(15)))?;
        let mut hs = snow::Builder::new(NOISE.parse()?)
            .local_private_key(my_dh_sk)
            .remote_public_key(remote_dh_pk)
            .psk(2, psk)
            .build_initiator()?;
        let mut buf = vec![0u8; MAX_FRAME];
        let n = hs.write_message(&[], &mut buf)?;
        write_frame(&mut s, &buf[..n])?;
        let m = read_frame(&mut s)?;
        hs.read_message(&m, &mut buf)
            .map_err(|_| anyhow!("handshake rejected (wrong code or not a member)"))?;
        let hh = hs.get_handshake_hash().to_vec();
        let ts = hs.into_transport_mode()?;
        s.set_read_timeout(None)?;
        Chan::wrap(s, ts, *remote_dh_pk, hh)
    }

    pub fn responder(mut s: TcpStream, my_dh_sk: &[u8; 32], psk: &[u8; 32]) -> Result<Chan> {
        s.set_nodelay(true).ok();
        s.set_read_timeout(Some(Duration::from_secs(15)))?;
        let mut hs = snow::Builder::new(NOISE.parse()?)
            .local_private_key(my_dh_sk)
            .psk(2, psk)
            .build_responder()?;
        let mut buf = vec![0u8; MAX_FRAME];
        let m = read_frame(&mut s)?;
        hs.read_message(&m, &mut buf)
            .map_err(|_| anyhow!("handshake failed"))?;
        let rs: Pk = hs
            .get_remote_static()
            .ok_or_else(|| anyhow!("no remote static"))?
            .try_into()?;
        let n = hs.write_message(&[], &mut buf)?;
        write_frame(&mut s, &buf[..n])?;
        let hh = hs.get_handshake_hash().to_vec();
        let ts = hs.into_transport_mode()?;
        s.set_read_timeout(None)?;
        Chan::wrap(s, ts, rs, hh)
    }

    fn wrap(s: TcpStream, ts: snow::TransportState, rs: Pk, hh: Vec<u8>) -> Result<Chan> {
        let r = s.try_clone()?;
        Ok(Chan {
            stream: Arc::new(Mutex::new(s)),
            reader: Arc::new(Mutex::new(r)),
            ts: Arc::new(Mutex::new(ts)),
            remote_static: rs,
            handshake_hash: hh,
        })
    }

    pub fn set_read_timeout(&self, d: Option<Duration>) {
        let _ = self.reader.lock().unwrap().set_read_timeout(d);
    }

    pub fn send(&self, m: &Msg) -> Result<()> {
        let pt = cbor(m);
        let mut framed = (pt.len() as u32).to_be_bytes().to_vec();
        framed.extend_from_slice(&pt);
        let mut s = self.stream.lock().unwrap();
        let mut buf = vec![0u8; MAX_FRAME];
        for chunk in framed.chunks(CHUNK) {
            let n = self.ts.lock().unwrap().write_message(chunk, &mut buf)?;
            write_frame(&mut s, &buf[..n])?;
        }
        Ok(())
    }

    /// Blocking receive. Returns Ok(None) on read timeout.
    pub fn recv(&self) -> Result<Option<Msg>> {
        let mut r = self.reader.lock().unwrap();
        let mut buf = vec![0u8; MAX_FRAME];
        let mut want: Option<usize> = None;
        let mut acc = Vec::new();
        loop {
            let f = match read_frame(&mut r) {
                Ok(f) => f,
                Err(e) => {
                    if acc.is_empty() && want.is_none() {
                        if let Some(io) = e.downcast_ref::<std::io::Error>() {
                            if matches!(
                                io.kind(),
                                std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut
                            ) {
                                return Ok(None);
                            }
                        }
                    }
                    return Err(e);
                }
            };
            let n = self
                .ts
                .lock()
                .unwrap()
                .read_message(&f, &mut buf)
                .map_err(|_| anyhow!("bad frame"))?;
            acc.extend_from_slice(&buf[..n]);
            if want.is_none() && acc.len() >= 4 {
                want = Some(u32::from_be_bytes(acc[..4].try_into().unwrap()) as usize);
                if want.unwrap() > 64 * 1024 * 1024 {
                    bail!("message too large");
                }
            }
            if let Some(w) = want {
                if acc.len() >= 4 + w {
                    return Ok(Some(uncbor(&acc[4..4 + w])?));
                }
            }
        }
    }

    pub fn shutdown(&self) {
        let _ = self
            .stream
            .lock()
            .unwrap()
            .shutdown(std::net::Shutdown::Both);
    }
}

/// Listening sockets for one session: bound to exactly the addresses put in the code
/// (plus loopback), all on the same port, instead of every interface (`[::]`). Traffic that
/// arrives on any other interface (cellular IMS, CGNAT IPv4, docker bridges...) finds
/// nothing listening.
pub struct Listener {
    socks: Vec<TcpListener>,
}

impl Listener {
    /// Non-blocking accept over all sockets.
    pub fn accept(&self) -> std::io::Result<(TcpStream, SocketAddr)> {
        for l in &self.socks {
            match l.accept() {
                Ok(x) => return Ok(x),
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                Err(e) => return Err(e),
            }
        }
        Err(std::io::ErrorKind::WouldBlock.into())
    }
}

fn bind_one(ip: IpAddr, port: u16) -> std::io::Result<TcpListener> {
    let s = Socket::new(
        if ip.is_ipv6() {
            Domain::IPV6
        } else {
            Domain::IPV4
        },
        Type::STREAM,
        None,
    )?;
    if ip.is_ipv6() {
        s.set_only_v6(true)?;
    }
    s.set_reuse_address(true)?;
    s.bind(&SocketAddr::new(ip, port).into())?;
    s.listen(16)?;
    let l: TcpListener = s.into();
    l.set_nonblocking(true)?;
    Ok(l)
}

/// Listen on a random port on every address in `local_addrs()` (and loopback, for
/// on-device tooling). Returns the listener, the port and the addresses that were
/// actually bound, which are what goes into the code.
pub fn listen() -> Result<(Listener, u16, Vec<String>)> {
    let want: Vec<IpAddr> = local_addrs()
        .iter()
        .filter_map(|a| a.parse().ok())
        .collect();
    for _attempt in 0..8 {
        let mut socks = Vec::new();
        let mut bound = Vec::new();
        let mut port = 0u16;
        for ip in want.iter().copied() {
            match bind_one(ip, port) {
                Ok(l) => {
                    if port == 0 {
                        port = l.local_addr()?.port();
                    }
                    socks.push(l);
                    bound.push(ip.to_string());
                }
                // port taken on this address by someone else: start over with a new port
                Err(e) if port != 0 && e.kind() == std::io::ErrorKind::AddrInUse => {
                    port = 0;
                    break;
                }
                // address went away / still tentative: just leave it out of the code
                Err(_) => {}
            }
        }
        if !bound.is_empty() && port == 0 {
            continue; // retry after a port clash
        }
        if bound.is_empty() {
            // no usable network: loopback only (a peer cannot reach us anyway)
            let l = bind_one(IpAddr::from([127, 0, 0, 1]), 0)?;
            let port = l.local_addr()?.port();
            return Ok((Listener { socks: vec![l] }, port, vec![]));
        }
        for lo in [
            IpAddr::from([127, 0, 0, 1]),
            IpAddr::from([0u16, 0, 0, 0, 0, 0, 0, 1]),
        ] {
            if let Ok(l) = bind_one(lo, port) {
                socks.push(l);
            }
        }
        return Ok((Listener { socks }, port, bound));
    }
    bail!("could not open a listening port")
}

/// Interfaces the platform says carry a usable (internet / LAN / VPN) network. On Android
/// the cellular IMS bearer (VoLTE) also sits on an `rmnet*` interface with a global IPv6
/// that apps can never use, so the app reports the right interface names from
/// ConnectivityManager. `None` = no information (desktop CLI, tests): use every interface.
static USABLE_IFACES: Mutex<Option<Vec<String>>> = Mutex::new(None);

pub fn set_usable_ifaces(names: Option<Vec<String>>) {
    *USABLE_IFACES.lock().unwrap() = names.filter(|v| !v.is_empty());
}

/// Addresses worth putting in a ticket: LAN IPv4, global/ULA IPv6. Ordered LAN-first.
pub fn local_addrs() -> Vec<String> {
    let usable = USABLE_IFACES.lock().unwrap().clone();
    let mut v4 = Vec::new();
    let mut v6 = Vec::new();
    if let Ok(ifs) = if_addrs::get_if_addrs() {
        for i in ifs {
            let n = i.name.as_str();
            let virtual_if = ["docker", "br-", "veth", "virbr", "lxc", "dummy"]
                .iter()
                .any(|p| n.starts_with(p));
            // ePDG = IMS over Wi-Fi tunnel, never reachable for apps
            let ims = ["epdg", "ims"].iter().any(|p| n.starts_with(p));
            if i.is_loopback() || virtual_if || ims {
                continue;
            }
            if let Some(u) = &usable {
                if !u.iter().any(|x| x == n) {
                    continue;
                }
            }
            // carrier IPv4 on mobile data is CGNAT and never reachable from outside
            let cellular = ["rmnet", "ccmni", "v4-", "clat"]
                .iter()
                .any(|p| n.starts_with(p));
            if cellular && i.ip().is_ipv4() {
                continue;
            }
            match i.ip() {
                IpAddr::V4(a) if !a.is_link_local() => v4.push(a.to_string()),
                IpAddr::V6(a) => {
                    let seg = a.segments()[0];
                    let link_local = (seg & 0xffc0) == 0xfe80;
                    if !link_local && !a.is_loopback() {
                        v6.push(a.to_string());
                    }
                }
                _ => {}
            }
        }
    }
    // private ranges first: they are the "near each other" path
    v4.sort_by_key(|a| {
        !(a.starts_with("192.168.") || a.starts_with("10.") || a.starts_with("172."))
    });
    v4.dedup();
    v6.dedup();
    v6.truncate(3);
    v4.into_iter().chain(v6).collect()
}

/// Try every address at once (LAN entries get a small head start); first success wins.
pub fn connect_any(addrs: &[String], port: u16) -> Result<TcpStream> {
    // Test hook for the desktop CLI (e.g. reaching an emulator through `adb forward`).
    let mut all: Vec<String> = addrs.to_vec();
    if let Ok(extra) = std::env::var("NV_CONNECT_EXTRA") {
        all.extend(
            extra
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty()),
        );
    }
    let addrs = &all;
    let (tx, rx) = std::sync::mpsc::channel();
    let mut n = 0;
    for (i, a) in addrs.iter().enumerate() {
        let Ok(ip) = a.parse::<IpAddr>() else {
            continue;
        };
        n += 1;
        let tx = tx.clone();
        let a = a.clone();
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(60 * i as u64));
            let r = TcpStream::connect_timeout(&SocketAddr::new(ip, port), Duration::from_secs(4))
                .map_err(|e| format!("{a}: {e}"));
            let _ = tx.send(r);
        });
    }
    drop(tx);
    let mut errs = Vec::new();
    for _ in 0..n {
        match rx.recv() {
            Ok(Ok(s)) => return Ok(s),
            Ok(Err(e)) => errs.push(e),
            Err(_) => break,
        }
    }
    Err(anyhow!(
        "could not reach the host ({})",
        if errs.is_empty() {
            "no usable address".into()
        } else {
            errs.join("; ")
        }
    ))
}
