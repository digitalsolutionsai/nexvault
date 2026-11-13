//! Log entries, operations, and the state folded from a workspace log.
//!
//! Keys: every workspace key ("epoch key") has a `key_id` = first 8 bytes of
//! hash(key). Encrypted items name the key they used, and a device keeps *every* key it
//! can unwrap. Concurrent approvals that each mint a different key for the same epoch
//! therefore never make data unreadable; the fold just picks a deterministic "current"
//! key for new writes.

use std::collections::{BTreeMap, BTreeSet};

use anyhow::{anyhow, bail, Result};
use serde::{Deserialize, Serialize};

use crate::crypto;

pub type Pk = [u8; 32];
pub type WsId = [u8; 16];
pub type SecretId = [u8; 16];
pub type FolderId = [u8; 16];
pub type KeyId = [u8; 8];

/// Limits that keep a hostile peer from exhausting memory or storage.
pub const MAX_ENTRY_BYTES: usize = 12 * 1024 * 1024;
pub const MAX_SECRET_CONTENT: usize = 10 * 1024 * 1024;
pub const MAX_NAME_LEN: usize = 200;
pub const MAX_MEMBERS: usize = 32;

pub fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

pub fn cbor<T: Serialize>(v: &T) -> Vec<u8> {
    let mut out = Vec::new();
    ciborium::into_writer(v, &mut out).expect("cbor encode");
    out
}

pub fn uncbor<T: for<'de> Deserialize<'de>>(b: &[u8]) -> Result<T> {
    ciborium::from_reader(b).map_err(|e| anyhow!("cbor decode: {e}"))
}

pub fn key_id(key: &[u8; 32]) -> KeyId {
    let h = crypto::hash(&[b"nv/key-id".as_slice(), key].concat());
    h[..8].try_into().unwrap()
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Member {
    pub name: String,
    #[serde(with = "serde_bytes")]
    pub sign_pk: Pk,
    #[serde(with = "serde_bytes")]
    pub dh_pk: Pk,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Wrap {
    #[serde(with = "serde_bytes")]
    pub to: Pk,
    #[serde(with = "serde_bytes")]
    pub eph: Pk,
    #[serde(with = "serde_bytes")]
    pub ct: Vec<u8>,
}

/// A workspace key wrapped for one member. `epoch` binds it into the AEAD context.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct KeyWrap {
    pub epoch: u32,
    pub wrap: Wrap,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum Change {
    /// Needs every current member. Proposed by the member who met the newcomer in person.
    Add { member: Member },
    /// Needs ⌈2/3⌉ of the members who stay. Rotates to a new epoch key.
    Remove {
        #[serde(with = "serde_bytes")]
        target: Pk,
    },
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Op {
    /// Founding charter. Must be co-signed by every member listed.
    Genesis {
        name: String,
        members: Vec<Member>,
        keys: Vec<KeyWrap>,
    },
    SecretPut {
        #[serde(with = "serde_bytes")]
        secret_id: SecretId,
        version: u32,
        #[serde(with = "serde_bytes")]
        key_id: KeyId,
        #[serde(with = "serde_bytes")]
        nonce: Vec<u8>,
        #[serde(with = "serde_bytes")]
        sealed: Vec<u8>,
    },
    SecretDelete {
        #[serde(with = "serde_bytes")]
        secret_id: SecretId,
    },
    FolderPut {
        #[serde(with = "serde_bytes")]
        folder_id: FolderId,
        version: u32,
        #[serde(with = "serde_bytes")]
        key_id: KeyId,
        #[serde(with = "serde_bytes")]
        nonce: Vec<u8>,
        #[serde(with = "serde_bytes")]
        sealed: Vec<u8>,
    },
    FolderDelete {
        #[serde(with = "serde_bytes")]
        folder_id: FolderId,
    },
    /// Audit trail: author viewed / copied / exported a secret.
    Audit {
        #[serde(with = "serde_bytes")]
        secret_id: SecretId,
        action: String,
    },
    /// Membership change. Counts as the proposer's approval. `keys` is filled when the
    /// proposer's own vote already reaches the threshold.
    Propose { change: Change, keys: Vec<KeyWrap> },
    /// `keys` is filled when this approval (as far as the author can see) completes it.
    Approve {
        #[serde(with = "serde_bytes")]
        proposal: [u8; 32],
        keys: Vec<KeyWrap>,
    },
    /// Fallback when concurrent approvals reached the threshold without anyone attaching keys.
    Keys {
        #[serde(with = "serde_bytes")]
        proposal: [u8; 32],
        keys: Vec<KeyWrap>,
    },
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Body {
    #[serde(with = "serde_bytes")]
    pub ws: WsId,
    #[serde(with = "serde_bytes")]
    pub author: Pk,
    pub seq: u64,
    pub ts: u64,
    pub op: Op,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Sig {
    #[serde(with = "serde_bytes")]
    pub by: Pk,
    #[serde(with = "serde_bytes")]
    pub sig: Vec<u8>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Entry {
    #[serde(with = "serde_bytes")]
    pub body: Vec<u8>,
    pub sigs: Vec<Sig>,
}

impl Entry {
    pub fn id(&self) -> [u8; 32] {
        crypto::hash(&self.body)
    }
    pub fn decode(&self) -> Result<Body> {
        uncbor(&self.body)
    }
    pub fn signed(body: &Body, sk: &[u8; 32]) -> Entry {
        let bytes = cbor(body);
        let sig = crypto::sign(sk, &bytes);
        Entry {
            body: bytes,
            sigs: vec![Sig {
                by: crypto::sign_pk(sk),
                sig,
            }],
        }
    }
    pub fn sig_valid(&self) -> bool {
        !self.sigs.is_empty()
            && self
                .sigs
                .iter()
                .all(|s| crypto::verify(&s.by, &self.body, &s.sig))
    }
    pub fn signed_by(&self, pk: &Pk) -> bool {
        self.sigs
            .iter()
            .any(|s| &s.by == pk && crypto::verify(pk, &self.body, &s.sig))
    }
}

/// Plaintext inside a SecretPut.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct SecretPayload {
    pub name: String,
    pub kind: String,
    #[serde(default)]
    pub note: String,
    /// Labelled fields (Key ID, Team ID…). Labels starting with '*' are secret.
    #[serde(default)]
    pub fields: Vec<(String, String)>,
    #[serde(default)]
    pub file_name: Option<String>,
    #[serde(default)]
    pub folder: Option<FolderId>,
    /// The secret itself (PEM text, .p12 bytes, password…). Only returned on reveal.
    #[serde(with = "serde_bytes")]
    pub content: Vec<u8>,
}

/// Plaintext inside a FolderPut.
#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct FolderPayload {
    pub name: String,
    #[serde(default)]
    pub parent: Option<FolderId>,
}

pub fn item_aad(ws: &WsId, id: &[u8; 16], version: u32, tag: &[u8]) -> Vec<u8> {
    [tag, ws.as_slice(), id.as_slice(), &version.to_be_bytes()].concat()
}

pub fn epoch_ctx(ws: &WsId, epoch: u32) -> Vec<u8> {
    [ws.as_slice(), &epoch.to_be_bytes()].concat()
}

#[derive(Clone, Debug)]
pub struct Sealed {
    pub entry_id: [u8; 32],
    pub author: Pk,
    pub version: u32,
    pub key_id: KeyId,
    pub ts: u64,
    pub nonce: Vec<u8>,
    pub sealed: Vec<u8>,
}

#[derive(Clone, Debug, Default)]
pub struct Item {
    pub versions: Vec<Sealed>,
    pub deleted: bool,
}

impl Item {
    /// Versions at the highest version number; more than one = concurrent edits.
    pub fn heads(&self) -> Vec<&Sealed> {
        let max = self.versions.iter().map(|v| v.version).max().unwrap_or(0);
        let mut h: Vec<&Sealed> = self.versions.iter().filter(|v| v.version == max).collect();
        h.sort_by_key(|v| std::cmp::Reverse((v.ts, v.entry_id)));
        h
    }
    pub fn next_version(&self) -> u32 {
        self.versions.iter().map(|v| v.version).max().unwrap_or(0) + 1
    }
}

#[derive(Clone, Debug)]
pub struct AuditEvent {
    pub author: Pk,
    pub ts: u64,
    pub secret_id: SecretId,
    pub action: String,
}

#[derive(Clone, Debug)]
pub struct Proposal {
    pub id: [u8; 32],
    pub proposer: Pk,
    pub change: Change,
    pub approvals: Vec<Pk>,
    pub ts: u64,
    /// threshold reached but nobody attached keys yet
    pub needs_keys: bool,
}

/// Everything derived from a log, from the point of view of one device.
#[derive(Clone, Debug, Default)]
pub struct State {
    pub ws: WsId,
    pub genesis_id: [u8; 32],
    pub name: String,
    pub members: Vec<Member>,
    pub removed: Vec<Member>,
    /// number of epochs so far (genesis = 1); global, independent of what this device holds
    pub epoch_count: u32,
    /// every key this device could unwrap: key_id -> (epoch, key)
    pub keys: BTreeMap<KeyId, (u32, [u8; 32])>,
    /// key used for new writes (deterministic across devices once logs match)
    pub current: Option<KeyId>,
    pub genesis_key: Option<[u8; 32]>,
    pub secrets: BTreeMap<SecretId, Item>,
    pub folders: BTreeMap<FolderId, Item>,
    pub audit: Vec<AuditEvent>,
    pub proposals: Vec<Proposal>,
    pub last_change: u64,
}

impl State {
    pub fn is_member(&self, pk: &Pk) -> bool {
        self.members.iter().any(|m| &m.sign_pk == pk)
    }
    pub fn member(&self, pk: &Pk) -> Option<&Member> {
        self.members
            .iter()
            .chain(self.removed.iter())
            .find(|m| &m.sign_pk == pk)
    }
    /// A newcomer whose Add proposal is still collecting approvals.
    pub fn pending_member(&self, pk: &Pk) -> Option<&Member> {
        self.proposals.iter().find_map(|p| match &p.change {
            Change::Add { member } if &member.sign_pk == pk => Some(member),
            _ => None,
        })
    }
    pub fn pending_by_dh(&self, dh: &Pk) -> Option<&Member> {
        self.proposals.iter().find_map(|p| match &p.change {
            Change::Add { member } if &member.dh_pk == dh => Some(member),
            _ => None,
        })
    }
    pub fn can_read(&self) -> bool {
        self.current.is_some()
    }
    pub fn current_key(&self) -> Option<(KeyId, [u8; 32])> {
        self.current
            .and_then(|id| self.keys.get(&id).map(|(_, k)| (id, *k)))
    }
    /// Tickets use the founding key so a member who has not synced since a removal can
    /// still join. Removed members can decrypt tickets but are refused at the handshake.
    pub fn ticket_key(&self) -> Option<[u8; 32]> {
        self.genesis_key.map(|k| crypto::hkdf32(&k, b"nv/ticket"))
    }
    pub fn item_key(&self, id: &KeyId) -> Option<[u8; 32]> {
        self.keys
            .get(id)
            .map(|(_, k)| crypto::hkdf32(k, b"nv/item"))
    }
    /// Seal bytes shown in the UI (first 9 bytes of hash(genesis id)).
    pub fn seal(&self) -> [u8; 9] {
        let h = crypto::hash(&self.genesis_id);
        h[..9].try_into().unwrap()
    }
    pub fn threshold(&self, change: &Change) -> usize {
        match change {
            Change::Add { .. } => self.members.len(),
            Change::Remove { target } => {
                let staying = self.members.iter().filter(|m| &m.sign_pk != target).count();
                (staying * 2).div_ceil(3).max(1)
            }
        }
    }
    /// Would one more approval (by `me`) complete this proposal?
    pub fn completes(&self, p: &Proposal, me: &Pk) -> bool {
        let n = p.approvals.len() + usize::from(!p.approvals.contains(me));
        n >= self.threshold(&p.change)
    }
    /// Who must receive the keys produced when `change` is applied.
    pub fn key_recipients(&self, change: &Change) -> Vec<Member> {
        match change {
            Change::Add { member } => vec![member.clone()],
            Change::Remove { target } => self
                .members
                .iter()
                .filter(|m| &m.sign_pk != target)
                .cloned()
                .collect(),
        }
    }
    /// Build the key wraps a completing entry must carry.
    pub fn make_keys(&self, change: &Change) -> Vec<KeyWrap> {
        match change {
            Change::Add { member } => self
                .keys
                .values()
                .map(|(epoch, k)| KeyWrap {
                    epoch: *epoch,
                    wrap: crypto::wrap_for(member, k, &epoch_ctx(&self.ws, *epoch)),
                })
                .collect(),
            Change::Remove { .. } => {
                let fresh: [u8; 32] = crypto::random();
                let epoch = self.epoch_count;
                self.key_recipients(change)
                    .iter()
                    .map(|m| KeyWrap {
                        epoch,
                        wrap: crypto::wrap_for(m, &fresh, &epoch_ctx(&self.ws, epoch)),
                    })
                    .collect()
            }
        }
    }
}

/// A workspace log plus validation on ingest.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct WsLog {
    #[serde(with = "serde_bytes")]
    pub ws: WsId,
    pub entries: Vec<Entry>,
}

fn is_genesis(b: &Body) -> bool {
    matches!(b.op, Op::Genesis { .. })
}

impl WsLog {
    /// version vector: author -> highest seq
    pub fn vv(&self) -> BTreeMap<Pk, u64> {
        let mut vv = BTreeMap::new();
        for e in &self.entries {
            if let Ok(b) = e.decode() {
                let s = vv.entry(b.author).or_insert(0);
                *s = (*s).max(b.seq);
            }
        }
        vv
    }

    pub fn next_seq(&self, author: &Pk) -> u64 {
        self.vv().get(author).copied().unwrap_or(0) + 1
    }

    /// Entries the other side is missing, in an order they can ingest.
    pub fn missing_for(&self, theirs: &BTreeMap<Pk, u64>) -> Vec<Entry> {
        let mut out: Vec<(bool, Pk, u64, Entry)> = Vec::new();
        for e in &self.entries {
            let Ok(b) = e.decode() else { continue };
            if b.seq > theirs.get(&b.author).copied().unwrap_or(0) {
                out.push((!is_genesis(&b), b.author, b.seq, e.clone()));
            }
        }
        out.sort_by_key(|a| (a.0, a.1, a.2));
        out.into_iter().map(|x| x.3).collect()
    }

    /// Validate and append. Ok(true) if new, Ok(false) if already known.
    pub fn ingest(&mut self, e: Entry) -> Result<bool> {
        if e.body.len() > MAX_ENTRY_BYTES {
            bail!("entry too large");
        }
        let b = e.decode()?;
        if b.ws != self.ws {
            bail!("entry for another workspace");
        }
        if !e.sig_valid() || !e.signed_by(&b.author) {
            bail!("bad signature");
        }
        let have = self.vv().get(&b.author).copied().unwrap_or(0);
        if b.seq <= have {
            return Ok(false);
        }
        if b.seq != have + 1 {
            bail!("gap in author sequence ({} after {})", b.seq, have);
        }
        let has_genesis = self
            .entries
            .iter()
            .any(|x| x.decode().map(|b| is_genesis(&b)).unwrap_or(false));
        match &b.op {
            Op::Genesis { members, name, .. } => {
                if has_genesis {
                    bail!("second genesis");
                }
                if members.len() < 2 || members.len() > MAX_MEMBERS || name.len() > MAX_NAME_LEN {
                    bail!("invalid charter");
                }
                if !members.iter().all(|m| e.signed_by(&m.sign_pk)) {
                    bail!("genesis not co-signed by every member");
                }
            }
            _ => {
                if !has_genesis {
                    bail!("entry before genesis");
                }
                let st = self.fold(None);
                if st.member(&b.author).is_none() {
                    bail!("author is not a member");
                }
            }
        }
        self.entries.push(e);
        Ok(true)
    }

    /// Fold the log into state. `me` = (sign_pk, dh_sk) to unwrap keys.
    pub fn fold(&self, me: Option<(&Pk, &[u8; 32])>) -> State {
        let mut st = State {
            ws: self.ws,
            ..Default::default()
        };
        let mut decoded: Vec<(Body, &Entry, [u8; 32])> = self
            .entries
            .iter()
            .filter_map(|e| e.decode().ok().map(|b| (b, e, e.id())))
            .collect();
        // genesis first, then a deterministic total order every device agrees on
        decoded.sort_by_key(|(a, _, ia)| (!is_genesis(a), a.ts, a.author, a.seq, *ia));

        let mut removed_at: BTreeMap<Pk, u64> = BTreeMap::new();
        let take_keys = |st: &mut State, keys: &[KeyWrap]| {
            let Some((pk, dh)) = me else { return };
            for kw in keys.iter().filter(|kw| &kw.wrap.to == pk) {
                if let Some(k) = crypto::unwrap(&kw.wrap, dh, &epoch_ctx(&st.ws, kw.epoch)) {
                    let id = key_id(&k);
                    st.keys.entry(id).or_insert((kw.epoch, k));
                    // newest epoch wins; within an epoch the first applied wins (deterministic)
                    let cur_epoch = st.current.and_then(|c| st.keys.get(&c)).map(|x| x.0);
                    if cur_epoch.is_none_or(|e| kw.epoch > e) {
                        st.current = Some(id);
                    }
                    if kw.epoch == 0 && st.genesis_key.is_none() {
                        st.genesis_key = Some(k);
                    }
                }
            }
        };

        for (b, _e, id) in decoded {
            if let Some(t) = removed_at.get(&b.author) {
                if b.ts >= *t {
                    continue; // written after removal took effect
                }
            }
            if !is_genesis(&b) && !st.is_member(&b.author) && !removed_at.contains_key(&b.author) {
                continue;
            }
            st.last_change = st.last_change.max(b.ts);
            // keys attached to the entry that completes a proposal
            let mut completing: Option<([u8; 32], Vec<KeyWrap>)> = None;
            match b.op {
                Op::Genesis {
                    name,
                    members,
                    keys,
                } => {
                    st.genesis_id = id;
                    st.name = name;
                    st.members = members;
                    st.epoch_count = 1;
                    take_keys(&mut st, &keys);
                }
                Op::SecretPut {
                    secret_id,
                    version,
                    key_id,
                    nonce,
                    sealed,
                } => {
                    let it = st.secrets.entry(secret_id).or_default();
                    it.deleted = false;
                    it.versions.push(Sealed {
                        entry_id: id,
                        author: b.author,
                        version,
                        key_id,
                        ts: b.ts,
                        nonce,
                        sealed,
                    });
                }
                Op::SecretDelete { secret_id } => {
                    if let Some(r) = st.secrets.get_mut(&secret_id) {
                        r.deleted = true;
                    }
                }
                Op::FolderPut {
                    folder_id,
                    version,
                    key_id,
                    nonce,
                    sealed,
                } => {
                    let it = st.folders.entry(folder_id).or_default();
                    it.deleted = false;
                    it.versions.push(Sealed {
                        entry_id: id,
                        author: b.author,
                        version,
                        key_id,
                        ts: b.ts,
                        nonce,
                        sealed,
                    });
                }
                Op::FolderDelete { folder_id } => {
                    if let Some(r) = st.folders.get_mut(&folder_id) {
                        r.deleted = true;
                    }
                }
                Op::Audit { secret_id, action } => {
                    st.audit.push(AuditEvent {
                        author: b.author,
                        ts: b.ts,
                        secret_id,
                        action,
                    });
                }
                Op::Propose { change, keys } => {
                    let valid = st.is_member(&b.author)
                        && st.members.len() < MAX_MEMBERS
                        && match &change {
                            Change::Add { member } => {
                                !st.is_member(&member.sign_pk) && member.name.len() <= MAX_NAME_LEN
                            }
                            Change::Remove { target } => {
                                st.is_member(target) && target != &b.author
                            }
                        }
                        && !st.proposals.iter().any(|p| p.change == change);
                    if valid {
                        st.proposals.push(Proposal {
                            id,
                            proposer: b.author,
                            change,
                            approvals: vec![b.author],
                            ts: b.ts,
                            needs_keys: false,
                        });
                        completing = Some((id, keys));
                    }
                }
                Op::Approve { proposal, keys } => {
                    if let Some(p) = st.proposals.iter_mut().find(|p| p.id == proposal) {
                        let target_self =
                            matches!(&p.change, Change::Remove { target } if target == &b.author);
                        if !target_self
                            && !p.approvals.contains(&b.author)
                            && st.members.iter().any(|m| m.sign_pk == b.author)
                        {
                            p.approvals.push(b.author);
                            completing = Some((proposal, keys));
                        }
                    }
                }
                Op::Keys { proposal, keys } => {
                    if st
                        .proposals
                        .iter()
                        .any(|p| p.id == proposal && p.needs_keys)
                    {
                        completing = Some((proposal, keys));
                    }
                }
            }
            if let Some((pid, keys)) = completing {
                let Some(idx) = st.proposals.iter().position(|p| p.id == pid) else {
                    continue;
                };
                let p = st.proposals[idx].clone();
                if p.approvals.len() < st.threshold(&p.change) {
                    continue;
                }
                // a valid key set must address every recipient
                let recips = st.key_recipients(&p.change);
                let covers = !keys.is_empty()
                    && recips
                        .iter()
                        .all(|m| keys.iter().any(|k| k.wrap.to == m.sign_pk));
                if !covers {
                    st.proposals[idx].needs_keys = true;
                    continue;
                }
                st.proposals.remove(idx);
                match p.change {
                    Change::Add { member } => {
                        st.members.push(member);
                        take_keys(&mut st, &keys);
                    }
                    Change::Remove { target } => {
                        if let Some(i) = st.members.iter().position(|m| m.sign_pk == target) {
                            st.removed.push(st.members.remove(i));
                            removed_at.insert(target, b.ts);
                        }
                        // the new key belongs to the next epoch; ignore wraps for any other epoch
                        let fresh: Vec<KeyWrap> = keys
                            .into_iter()
                            .filter(|k| k.epoch == st.epoch_count)
                            .collect();
                        st.epoch_count += 1;
                        take_keys(&mut st, &fresh);
                        // proposals about the removed member are void
                        st.proposals.retain(|q| match &q.change {
                            Change::Remove { target: t } => t != &target,
                            Change::Add { .. } => true,
                        });
                        for q in st.proposals.iter_mut() {
                            q.approvals.retain(|a| a != &target);
                        }
                    }
                }
            }
        }
        st
    }
}

/// Folder tree helpers (cycles and dangling parents fall back to the root).
pub fn folder_path(
    folders: &BTreeMap<FolderId, (String, Option<FolderId>)>,
    mut id: Option<FolderId>,
) -> Vec<FolderId> {
    let mut path = Vec::new();
    let mut seen = BTreeSet::new();
    while let Some(f) = id {
        if !seen.insert(f) || !folders.contains_key(&f) {
            return path; // cycle or missing: treat the rest as root
        }
        path.insert(0, f);
        id = folders[&f].1;
    }
    path
}
