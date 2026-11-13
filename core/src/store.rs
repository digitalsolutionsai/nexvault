//! The on-device vault: identity + workspace logs, encrypted at rest with a master key
//! that the app keeps in Android Keystore / iOS Keychain.

use std::collections::BTreeMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use anyhow::{anyhow, bail, Context, Result};
use serde::{Deserialize, Serialize};
use zeroize::{Zeroize, ZeroizeOnDrop};

use crate::crypto;
use crate::model::*;

#[derive(Serialize, Deserialize, Clone, Zeroize, ZeroizeOnDrop)]
pub struct Identity {
    pub name: String,
    pub sign_sk: [u8; 32],
    pub dh_sk: [u8; 32],
}

impl Identity {
    pub fn generate(name: &str) -> Self {
        Identity {
            name: name.to_string(),
            sign_sk: crypto::random(),
            dh_sk: crypto::random(),
        }
    }
    pub fn sign_pk(&self) -> Pk {
        crypto::sign_pk(&self.sign_sk)
    }
    pub fn dh_pk(&self) -> Pk {
        crypto::dh_pk(&self.dh_sk)
    }
    pub fn member(&self) -> Member {
        Member {
            name: self.name.clone(),
            sign_pk: self.sign_pk(),
            dh_pk: self.dh_pk(),
        }
    }
}

/// Local-only bookkeeping that is not part of the shared log.
#[derive(Serialize, Deserialize, Clone, Default)]
pub struct WsLocal {
    /// member sign_pk -> last time we completed a sync with them (ms)
    #[serde(default)]
    pub last_sync: BTreeMap<Pk, u64>,
    /// set while this device is a newcomer waiting for approvals: lets it read sync codes
    #[serde(default)]
    pub pending_ticket_key: Option<[u8; 32]>,
    /// set after restoring a backup: this device may have authored entries after the backup
    /// was taken, so writing now could reuse sequence numbers. Cleared by the next finished sync.
    #[serde(default)]
    pub stale: bool,
}

pub const VAULT_VERSION: u32 = 2;

#[derive(Serialize, Deserialize, Clone)]
pub struct VaultData {
    #[serde(default)]
    pub version: u32,
    pub identity: Option<Identity>,
    pub workspaces: Vec<WsLog>,
    #[serde(default)]
    pub local: BTreeMap<WsId, WsLocal>,
}

pub struct Vault {
    pub data: VaultData,
    path: PathBuf,
    key: [u8; 32],
}

impl Drop for Vault {
    fn drop(&mut self) {
        self.key.zeroize();
    }
}

impl Vault {
    /// Constant-time check that `k` is this vault's key (re-authentication after a biometric scan).
    pub fn key_matches(&self, k: &[u8]) -> bool {
        k.len() == 32 && self.key.iter().zip(k).fold(0u8, |a, (x, y)| a | (x ^ y)) == 0
    }

    /// Copy of the vault key, for sealing under the platform biometric key. Callers must zeroize it.
    pub fn key_copy(&self) -> zeroize::Zeroizing<[u8; 32]> {
        zeroize::Zeroizing::new(self.key)
    }
}

const MAGIC: &[u8] = b"NXV2";
const BACKUP_MAGIC: &[u8] = b"NXB1";

fn decrypt_file(raw: &[u8], key: &[u8; 32]) -> Result<VaultData> {
    if raw.len() < 4 + 24 || &raw[..4] != MAGIC {
        bail!("vault file is not a NexVault vault");
    }
    let mut pt = crypto::open(key, &raw[4..28], MAGIC, &raw[28..])
        .map_err(|_| anyhow!("wrong master key or corrupted vault"))?;
    let d: VaultData = uncbor(&pt)?;
    pt.zeroize();
    if d.version > VAULT_VERSION {
        bail!("vault was written by a newer NexVault; update the app");
    }
    Ok(d)
}

impl Vault {
    pub fn open(dir: &Path, key: [u8; 32]) -> Result<Vault> {
        fs::create_dir_all(dir).with_context(|| format!("create {}", dir.display()))?;
        let path = dir.join("vault.bin");
        let bak = dir.join("vault.bak");
        let data = if path.exists() {
            match decrypt_file(&fs::read(&path)?, &key) {
                Ok(d) => d,
                // torn write or bit rot: fall back to the previous good copy
                Err(e) => match bak
                    .exists()
                    .then(|| {
                        fs::read(&bak)
                            .ok()
                            .and_then(|b| decrypt_file(&b, &key).ok())
                    })
                    .flatten()
                {
                    Some(d) => d,
                    None => return Err(e),
                },
            }
        } else {
            VaultData {
                version: VAULT_VERSION,
                identity: None,
                workspaces: vec![],
                local: BTreeMap::new(),
            }
        };
        Ok(Vault { data, path, key })
    }

    /// Atomic, durable write: tmp file + fsync + keep previous as .bak + rename.
    pub fn save(&mut self) -> Result<()> {
        self.data.version = VAULT_VERSION;
        let mut pt = cbor(&self.data);
        let (nonce, ct) = crypto::seal(&self.key, MAGIC, &pt);
        pt.zeroize();
        let tmp = self.path.with_extension("tmp");
        {
            let mut f = fs::File::create(&tmp)?;
            f.write_all(&[MAGIC, &nonce, &ct].concat())?;
            f.sync_all()?;
        }
        if self.path.exists() {
            let _ = fs::copy(&self.path, self.path.with_extension("bak"));
        }
        fs::rename(&tmp, &self.path)?;
        if let Some(dir) = self.path.parent() {
            if let Ok(d) = fs::File::open(dir) {
                let _ = d.sync_all();
            }
        }
        Ok(())
    }

    pub fn identity(&self) -> Result<&Identity> {
        self.data
            .identity
            .as_ref()
            .ok_or_else(|| anyhow!("no identity yet"))
    }

    pub fn ws(&self, id: &WsId) -> Result<&WsLog> {
        self.data
            .workspaces
            .iter()
            .find(|w| &w.ws == id)
            .ok_or_else(|| anyhow!("unknown workspace"))
    }

    pub fn ws_mut(&mut self, id: &WsId) -> Result<&mut WsLog> {
        self.data
            .workspaces
            .iter_mut()
            .find(|w| &w.ws == id)
            .ok_or_else(|| anyhow!("unknown workspace"))
    }

    pub fn state(&self, id: &WsId) -> Result<State> {
        let me = self.identity()?;
        let pk = me.sign_pk();
        Ok(self.ws(id)?.fold(Some((&pk, &me.dh_sk))))
    }

    /// Ticket key for this workspace: from the log, or the one handed over at onboarding.
    pub fn ticket_key(&self, id: &WsId) -> Result<[u8; 32]> {
        if let Some(k) = self.state(id)?.ticket_key() {
            return Ok(k);
        }
        self.data
            .local
            .get(id)
            .and_then(|l| l.pending_ticket_key)
            .ok_or_else(|| anyhow!("no workspace key on this device"))
    }

    /// Append an entry authored by this device.
    pub fn append(&mut self, ws: &WsId, op: Op) -> Result<Entry> {
        if self.data.local.get(ws).is_some_and(|l| l.stale) {
            bail!("restored from a backup: sync with a member before making changes");
        }
        let me = self.identity()?.clone();
        let log = self.ws_mut(ws)?;
        let body = Body {
            ws: *ws,
            author: me.sign_pk(),
            seq: log.next_seq(&me.sign_pk()),
            ts: now_ms(),
            op,
        };
        let e = Entry::signed(&body, &me.sign_sk);
        log.ingest(e.clone())?;
        Ok(e)
    }

    fn seal_item(
        st: &State,
        id: &[u8; 16],
        version: u32,
        tag: &[u8],
        pt: &[u8],
    ) -> Result<(KeyId, Vec<u8>, Vec<u8>)> {
        let (kid, _) = st
            .current_key()
            .ok_or_else(|| anyhow!("this device has no workspace key"))?;
        let key = st.item_key(&kid).unwrap();
        let (nonce, ct) = crypto::seal(&key, &item_aad(&st.ws, id, version, tag), pt);
        Ok((kid, nonce, ct))
    }

    pub fn put_secret(
        &mut self,
        ws: &WsId,
        id: Option<SecretId>,
        payload: &SecretPayload,
    ) -> Result<SecretId> {
        if payload.content.len() > MAX_SECRET_CONTENT {
            bail!("secret is larger than 10 MB");
        }
        if payload.name.trim().is_empty() || payload.name.len() > MAX_NAME_LEN {
            bail!("invalid name");
        }
        let st = self.state(ws)?;
        if let Some(f) = payload.folder {
            if st.folders.get(&f).is_none_or(|x| x.deleted) {
                bail!("folder does not exist");
            }
        }
        let secret_id = id.unwrap_or_else(crypto::random);
        let version = st
            .secrets
            .get(&secret_id)
            .map(|r| r.next_version())
            .unwrap_or(1);
        let mut pt = cbor(payload);
        let (key_id, nonce, sealed) = Self::seal_item(&st, &secret_id, version, b"secret", &pt)?;
        pt.zeroize();
        self.append(
            ws,
            Op::SecretPut {
                secret_id,
                version,
                key_id,
                nonce,
                sealed,
            },
        )?;
        Ok(secret_id)
    }

    pub fn open_secret(&self, st: &State, id: &SecretId, v: &Sealed) -> Result<SecretPayload> {
        let key = st
            .item_key(&v.key_id)
            .ok_or_else(|| anyhow!("this device does not hold the key for this item"))?;
        let mut pt = crypto::open(
            &key,
            &v.nonce,
            &item_aad(&st.ws, id, v.version, b"secret"),
            &v.sealed,
        )?;
        let p = uncbor(&pt);
        pt.zeroize();
        p
    }

    pub fn put_folder(
        &mut self,
        ws: &WsId,
        id: Option<FolderId>,
        payload: &FolderPayload,
    ) -> Result<FolderId> {
        if payload.name.trim().is_empty() || payload.name.len() > MAX_NAME_LEN {
            bail!("invalid name");
        }
        let st = self.state(ws)?;
        let folder_id = id.unwrap_or_else(crypto::random);
        if let Some(p) = payload.parent {
            if st.folders.get(&p).is_none_or(|x| x.deleted) {
                bail!("parent folder does not exist");
            }
            // refuse to move a folder under itself
            let tree = self.folder_tree(&st);
            if folder_path(&tree, Some(p)).contains(&folder_id) {
                bail!("cannot move a folder into itself");
            }
        }
        let version = st
            .folders
            .get(&folder_id)
            .map(|r| r.next_version())
            .unwrap_or(1);
        let (key_id, nonce, sealed) =
            Self::seal_item(&st, &folder_id, version, b"folder", &cbor(payload))?;
        self.append(
            ws,
            Op::FolderPut {
                folder_id,
                version,
                key_id,
                nonce,
                sealed,
            },
        )?;
        Ok(folder_id)
    }

    pub fn open_folder(&self, st: &State, id: &FolderId, v: &Sealed) -> Result<FolderPayload> {
        let key = st
            .item_key(&v.key_id)
            .ok_or_else(|| anyhow!("this device does not hold the key for this item"))?;
        uncbor(&crypto::open(
            &key,
            &v.nonce,
            &item_aad(&st.ws, id, v.version, b"folder"),
            &v.sealed,
        )?)
    }

    /// id -> (name, parent) for live folders this device can read.
    pub fn folder_tree(&self, st: &State) -> BTreeMap<FolderId, (String, Option<FolderId>)> {
        st.folders
            .iter()
            .filter(|(_, it)| !it.deleted)
            .filter_map(|(id, it)| {
                self.open_folder(st, id, it.heads()[0])
                    .ok()
                    .map(|p| (*id, (p.name, p.parent)))
            })
            .collect()
    }

    pub fn propose(&mut self, ws: &WsId, change: Change) -> Result<()> {
        let st = self.state(ws)?;
        let me = self.identity()?.sign_pk();
        if st.proposals.iter().any(|p| p.change == change) {
            bail!("this change is already proposed");
        }
        match &change {
            Change::Remove { target } if !st.is_member(target) || target == &me => {
                bail!("cannot remove this member")
            }
            Change::Add { member } if st.is_member(&member.sign_pk) => bail!("already a member"),
            _ => {}
        }
        let keys = if st.threshold(&change) <= 1 {
            st.make_keys(&change)
        } else {
            vec![]
        };
        self.append(ws, Op::Propose { change, keys })?;
        Ok(())
    }

    pub fn approve(&mut self, ws: &WsId, proposal: &[u8; 32]) -> Result<()> {
        let st = self.state(ws)?;
        let me = self.identity()?.sign_pk();
        let p = st
            .proposals
            .iter()
            .find(|p| &p.id == proposal)
            .ok_or_else(|| anyhow!("unknown proposal"))?;
        let keys = if st.completes(p, &me) {
            st.make_keys(&p.change)
        } else {
            vec![]
        };
        self.append(
            ws,
            Op::Approve {
                proposal: *proposal,
                keys,
            },
        )?;
        Ok(())
    }

    /// Supply keys for proposals that reached their threshold without them.
    /// Returns how many were fixed. Called after every sync.
    pub fn maintain(&mut self, ws: &WsId) -> Result<usize> {
        let st = self.state(ws)?;
        let me = self.identity()?.sign_pk();
        if !st.is_member(&me) || !st.can_read() || self.data.local.get(ws).is_some_and(|l| l.stale)
        {
            return Ok(0);
        }
        let todo: Vec<Proposal> = st
            .proposals
            .iter()
            .filter(|p| p.needs_keys)
            .cloned()
            .collect();
        for p in &todo {
            self.append(
                ws,
                Op::Keys {
                    proposal: p.id,
                    keys: st.make_keys(&p.change),
                },
            )?;
        }
        Ok(todo.len())
    }

    /// Passphrase-encrypted copy of the whole vault (identity included) for device loss.
    pub fn export_backup(&self, passphrase: &str) -> Result<Vec<u8>> {
        if passphrase.chars().count() < 10 {
            bail!("passphrase must be at least 10 characters");
        }
        let salt: [u8; 16] = crypto::random();
        let k = crypto::passphrase_key(passphrase, &salt, true)?;
        let mut pt = cbor(&self.data);
        let (nonce, ct) = crypto::seal(&k, BACKUP_MAGIC, &pt);
        pt.zeroize();
        Ok([BACKUP_MAGIC, &salt, &nonce, &ct].concat())
    }

    /// Replace this (empty) vault with a backup.
    pub fn import_backup(&mut self, blob: &[u8], passphrase: &str) -> Result<()> {
        if self.data.identity.is_some() {
            bail!("this device already has an identity");
        }
        if blob.len() < 4 + 16 + 24 + 16 || &blob[..4] != BACKUP_MAGIC {
            bail!("not a NexVault backup");
        }
        let k = crypto::passphrase_key(passphrase, &blob[4..20], true)?;
        let mut pt = crypto::open(&k, &blob[20..44], BACKUP_MAGIC, &blob[44..])
            .map_err(|_| anyhow!("wrong passphrase"))?;
        self.data = uncbor(&pt)?;
        let ids: Vec<WsId> = self.data.workspaces.iter().map(|w| w.ws).collect();
        for ws in ids {
            self.data.local.entry(ws).or_default().stale = true;
        }
        pt.zeroize();
        self.save()
    }
}
