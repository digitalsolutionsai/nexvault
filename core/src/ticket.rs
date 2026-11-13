//! Sync tickets (encrypted, for existing members) and ceremony invites (plain, in person).

use anyhow::{anyhow, bail, Result};
use base64::engine::general_purpose::URL_SAFE_NO_PAD as B64;
use base64::Engine;
use serde::{Deserialize, Serialize};

use crate::crypto;
use crate::model::*;

pub const TICKET_PREFIX: &str = "nexvault://t/";
pub const INVITE_PREFIX: &str = "nexvault://i/";

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct TicketInner {
    pub v: u8,
    #[serde(with = "serde_bytes")]
    pub host: Pk,
    pub addrs: Vec<String>,
    pub port: u16,
    #[serde(with = "serde_bytes")]
    pub psk: [u8; 32],
    pub exp: u64,
}

#[derive(Serialize, Deserialize)]
struct TicketSigned {
    #[serde(with = "serde_bytes")]
    inner: Vec<u8>,
    #[serde(with = "serde_bytes")]
    sig: Vec<u8>,
}

/// nexvault://t/<b64( ws_id(16) | nonce(24) | XChaCha(ticket_key, TicketSigned) )>
pub fn encode_ticket(
    ws: &WsId,
    ticket_key: &[u8; 32],
    t: &TicketInner,
    sign_sk: &[u8; 32],
) -> String {
    let inner = cbor(t);
    let sig = crypto::sign(sign_sk, &inner);
    let (nonce, ct) = crypto::seal(ticket_key, ws, &cbor(&TicketSigned { inner, sig }));
    format!(
        "{TICKET_PREFIX}{}",
        B64.encode([ws.as_slice(), &nonce, &ct].concat())
    )
}

pub fn ticket_ws(s: &str) -> Result<WsId> {
    let raw = B64
        .decode(
            s.trim()
                .strip_prefix(TICKET_PREFIX)
                .ok_or_else(|| anyhow!("not a sync code"))?,
        )
        .map_err(|_| anyhow!("code is damaged or incomplete"))?;
    if raw.len() < 16 + 24 + 16 {
        bail!("code is damaged or incomplete");
    }
    Ok(raw[..16].try_into().unwrap())
}

pub fn decode_ticket(s: &str, ticket_key: &[u8; 32]) -> Result<TicketInner> {
    let raw = B64
        .decode(
            s.trim()
                .strip_prefix(TICKET_PREFIX)
                .ok_or_else(|| anyhow!("not a sync code"))?,
        )
        .map_err(|_| anyhow!("code is damaged or incomplete"))?;
    if raw.len() < 16 + 24 + 16 {
        bail!("code is damaged or incomplete");
    }
    let ws = &raw[..16];
    let pt = crypto::open(ticket_key, &raw[16..40], ws, &raw[40..])
        .map_err(|_| anyhow!("this sync code is not for a workspace on this device"))?;
    let ts: TicketSigned = uncbor(&pt)?;
    let t: TicketInner = uncbor(&ts.inner)?;
    if !crypto::verify(&t.host, &ts.inner, &ts.sig) {
        bail!("sync code signature is invalid");
    }
    if t.exp < now_ms() {
        bail!("sync code has expired");
    }
    Ok(t)
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Invite {
    pub v: u8,
    pub ws_name: String,
    /// Some(id) when inviting into an existing workspace (member add), None for a new one.
    #[serde(default)]
    pub ws: Option<WsId>,
    pub creator: Member,
    pub addrs: Vec<String>,
    pub port: u16,
    #[serde(with = "serde_bytes")]
    pub psk: [u8; 32],
    pub exp: u64,
}

pub fn encode_invite(i: &Invite) -> String {
    format!("{INVITE_PREFIX}{}", B64.encode(cbor(i)))
}

pub fn decode_invite(s: &str) -> Result<Invite> {
    let raw = B64
        .decode(
            s.trim()
                .strip_prefix(INVITE_PREFIX)
                .ok_or_else(|| anyhow!("not an invite code"))?,
        )
        .map_err(|_| anyhow!("code is damaged or incomplete"))?;
    let i: Invite = uncbor(&raw).map_err(|_| anyhow!("code is damaged or incomplete"))?;
    if i.exp < now_ms() {
        bail!("invite has expired");
    }
    Ok(i)
}
