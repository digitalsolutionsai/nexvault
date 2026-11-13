//! JSON command API used by both the FFI (Flutter) and the `nv` CLI.
//! Request: {"cmd": "...", ...}. Response: {"ok": true, "data": ...} | {"ok": false, "error": "..."}.

use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use anyhow::{anyhow, bail, Result};
use base64::engine::general_purpose::STANDARD as B64;
use base64::Engine;
use serde_json::{json, Value};
use zeroize::Zeroize;

use crate::ceremony::{self, CreatorSession, JoinCeremony};
use crate::crypto;
use crate::model::*;
use crate::store::{Identity, Vault};
use crate::sync::{self, HostSession, JoinSession, SharedVault};
use crate::ticket;

#[derive(Default)]
pub struct Api {
    vault: Option<SharedVault>,
    host: Option<Arc<HostSession>>,
    join: Option<Arc<JoinSession>>,
    creator: Option<Arc<CreatorSession>>,
    cjoin: Option<Arc<JoinCeremony>>,
}

fn s<'a>(v: &'a Value, k: &str) -> Result<&'a str> {
    v.get(k)
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("missing '{k}'"))
}

fn opt<'a>(v: &'a Value, k: &str) -> Option<&'a str> {
    v.get(k).and_then(|x| x.as_str()).filter(|x| !x.is_empty())
}

fn arr<const N: usize>(hex_str: &str) -> Result<[u8; N]> {
    hex::decode(hex_str)?
        .try_into()
        .map_err(|_| anyhow!("bad id length"))
}

fn opt_id<const N: usize>(v: &Value, k: &str) -> Result<Option<[u8; N]>> {
    opt(v, k).map(arr::<N>).transpose()
}

/// Fields whose label starts with '*' are secret: only `reveal` returns their values.
fn public_fields(f: &[(String, String)]) -> Vec<(String, String)> {
    f.iter()
        .map(|(k, v)| {
            if k.starts_with('*') {
                (k.clone(), String::new())
            } else {
                (k.clone(), v.clone())
            }
        })
        .collect()
}

impl Api {
    pub fn call(&mut self, req: &str) -> String {
        let out = serde_json::from_str::<Value>(req)
            .map_err(|e| anyhow!("bad request: {e}"))
            .and_then(|v| self.dispatch(&v));
        match out {
            Ok(data) => json!({"ok": true, "data": data}).to_string(),
            Err(e) => json!({"ok": false, "error": e.to_string()}).to_string(),
        }
    }

    fn vault(&self) -> Result<SharedVault> {
        self.vault.clone().ok_or_else(|| anyhow!("vault is locked"))
    }

    /// Run `f` with the vault locked, then save if it returned Ok.
    fn write<T>(&self, f: impl FnOnce(&mut Vault) -> Result<T>) -> Result<T> {
        let vault = self.vault()?;
        let mut v = vault.lock().unwrap();
        let out = f(&mut v)?;
        v.save()?;
        Ok(out)
    }

    fn read<T>(&self, f: impl FnOnce(&Vault) -> Result<T>) -> Result<T> {
        let vault = self.vault()?;
        let v = vault.lock().unwrap();
        f(&v)
    }

    fn dispatch(&mut self, r: &Value) -> Result<Value> {
        let cmd = s(r, "cmd")?;
        match cmd {
            // ---- vault lifecycle
            // Open with a raw key: desktop CLI and tests only. The app never handles the key:
            // it uses the pin_* commands below, or the biometric JNI path (jni.rs).
            "open" => {
                let mut key: [u8; 32] = arr(s(r, "key")?)?;
                let out = self.open_with_key(s(r, "dir")?, &key);
                key.zeroize();
                out
            }
            // First run: the master key is generated here and never leaves the core.
            "pin_setup" => {
                let key = zeroize::Zeroizing::new(crypto::random::<32>());
                let blob = crypto::pin_wrap(s(r, "pin")?, &key)?;
                self.open_with_key(s(r, "dir")?, &key)?;
                Ok(json!({"blob": hex::encode(blob)}))
            }
            // Device-lock custody: the key is generated here and sealed by the platform
            // (Keystore / Keychain behind biometrics or the device passcode). No PIN.
            "device_setup" => {
                let key = zeroize::Zeroizing::new(crypto::random::<32>());
                self.open_with_key(s(r, "dir")?, &key)?;
                Ok(json!(null))
            }
            // Recovery code for the open vault: 120 random bits shown once to the user, and a
            // blob of the key wrapped by it (Argon2id). Replaces any previous code.
            "recovery_new" => {
                let key = self.key_copy().ok_or_else(|| anyhow!("vault is locked"))?;
                let code = crypto::recovery_code();
                let blob = crypto::pin_wrap(&crypto::normalize_recovery(&code), &key)?;
                Ok(json!({"code": code, "blob": hex::encode(blob)}))
            }
            // Wrap the open vault's key under a new PIN (moving from device custody to PIN).
            "pin_set" => {
                let key = self.key_copy().ok_or_else(|| anyhow!("vault is locked"))?;
                Ok(json!({"blob": hex::encode(crypto::pin_wrap(s(r, "pin")?, &key)?)}))
            }
            "recovery_open" => {
                let code = crypto::normalize_recovery(s(r, "code")?);
                let key = crypto::pin_unwrap(&code, &hex::decode(s(r, "blob")?)?)
                    .map_err(|_| anyhow!("wrong recovery code"))?;
                self.open_with_key(s(r, "dir")?, &key)
            }
            "pin_open" => {
                let key = crypto::pin_unwrap(s(r, "pin")?, &hex::decode(s(r, "blob")?)?)?;
                self.open_with_key(s(r, "dir")?, &key)
            }
            // Re-authentication: the PIN must unwrap the key of the vault that is open.
            "pin_check" => {
                let key = crypto::pin_unwrap(s(r, "pin")?, &hex::decode(s(r, "blob")?)?)?;
                if !self.key_matches(key.as_slice()) {
                    bail!("wrong PIN");
                }
                Ok(json!(null))
            }
            "pin_change" => {
                let key = crypto::pin_unwrap(s(r, "old")?, &hex::decode(s(r, "blob")?)?)?;
                if !self.key_matches(key.as_slice()) {
                    bail!("wrong PIN");
                }
                Ok(json!({"blob": hex::encode(crypto::pin_wrap(s(r, "new")?, &key)?)}))
            }
            "lock" => {
                self.stop_all();
                self.vault = None;
                Ok(json!(null))
            }
            "create_identity" => {
                let name = s(r, "name")?.trim().to_string();
                if name.is_empty() || name.len() > MAX_NAME_LEN {
                    bail!("invalid name");
                }
                self.write(|v| {
                    if v.data.identity.is_some() {
                        bail!("identity already exists");
                    }
                    v.data.identity = Some(Identity::generate(&name));
                    Ok(json!({"pk": hex::encode(v.identity()?.sign_pk())}))
                })
            }
            "me" => self.read(|v| {
                let i = v.identity()?;
                Ok(json!({"name": i.name, "pk": hex::encode(i.sign_pk()), "device": hex::encode(&crypto::hash(&i.sign_pk())[..4])}))
            }),
            "backup_export" => {
                let blob = self.read(|v| v.export_backup(s(r, "passphrase")?))?;
                Ok(json!({"b64": B64.encode(blob)}))
            }
            "backup_import" => {
                let blob = B64.decode(s(r, "b64")?)?;
                self.write(|v| v.import_backup(&blob, s(r, "passphrase")?))?;
                Ok(json!(null))
            }

            // ---- reading
            "workspaces" => self.read(|v| v.data.workspaces.iter().map(|w| ws_summary(v, &w.ws)).collect::<Result<Vec<_>>>().map(Value::from)),
            "workspace" => self.read(|v| workspace_detail(v, &arr(s(r, "ws")?)?)),
            "secret" => self.read(|v| {
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: SecretId = arr(s(r, "id")?)?;
                let st = v.state(&ws)?;
                let it = st.secrets.get(&id).filter(|i| !i.deleted).ok_or_else(|| anyhow!("unknown secret"))?;
                let heads = it.heads();
                let meta = v.open_secret(&st, &id, heads[0])?;
                let name_of = |pk: &Pk| st.member(pk).map(|m| m.name.clone()).unwrap_or_else(|| "?".into());
                let mut history: Vec<Value> = it
                    .versions
                    .iter()
                    .map(|x| json!({"who": name_of(&x.author), "action": if x.version == 1 {"created"} else {"edited"}, "ts": x.ts}))
                    .collect();
                history.extend(st.audit.iter().filter(|a| a.secret_id == id).map(|a| json!({"who": name_of(&a.author), "action": a.action, "ts": a.ts})));
                history.sort_by(|a, b| b["ts"].as_u64().cmp(&a["ts"].as_u64()));
                let conflicts: Vec<Value> = heads
                    .iter()
                    .map(|h| json!({"entry": hex::encode(h.entry_id), "who": name_of(&h.author), "ts": h.ts,
                        "name": v.open_secret(&st, &id, h).map(|p| p.name).unwrap_or_default()}))
                    .collect();
                Ok(json!({
                    "id": hex::encode(id), "name": meta.name, "kind": meta.kind, "note": meta.note,
                    "fields": public_fields(&meta.fields), "file_name": meta.file_name, "size": meta.content.len(),
                    "folder": meta.folder.map(hex::encode),
                    "version": heads[0].version, "conflict": heads.len() > 1, "versions": conflicts, "history": history,
                }))
            }),
            "reveal" => {
                // decrypts one version (default: newest head) and records an audit entry
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: SecretId = arr(s(r, "id")?)?;
                let entry = opt_id::<32>(r, "entry")?;
                let action = opt(r, "action").unwrap_or("viewed").to_string();
                if !["viewed", "copied", "exported"].contains(&action.as_str()) {
                    bail!("bad action");
                }
                self.write(|v| {
                    let st = v.state(&ws)?;
                    let it = st.secrets.get(&id).ok_or_else(|| anyhow!("unknown secret"))?;
                    let ver = match entry {
                        Some(e) => it.versions.iter().find(|x| x.entry_id == e).ok_or_else(|| anyhow!("unknown version"))?,
                        None => it.heads()[0],
                    };
                    let meta = v.open_secret(&st, &id, ver)?;
                    v.append(&ws, Op::Audit { secret_id: id, action })?;
                    Ok(json!({
                        "content_b64": B64.encode(&meta.content),
                        "text": String::from_utf8(meta.content.clone()).ok(),
                        "file_name": meta.file_name,
                        "secret_fields": meta.fields.iter().filter(|(k, _)| k.starts_with('*')).cloned().collect::<Vec<_>>(),
                    }))
                })
            }

            // ---- writing
            "put_secret" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                let id = opt_id::<16>(r, "id")?;
                let content = match (opt(r, "content_b64"), r.get("text").and_then(|x| x.as_str())) {
                    (Some(b), _) => B64.decode(b)?,
                    (None, Some(t)) => t.as_bytes().to_vec(),
                    _ => bail!("missing content"),
                };
                let fields: Vec<(String, String)> = r.get("fields").and_then(|f| serde_json::from_value(f.clone()).ok()).unwrap_or_default();
                let mut p = SecretPayload {
                    name: s(r, "name")?.trim().to_string(),
                    kind: opt(r, "kind").unwrap_or("text").to_string(),
                    note: opt(r, "note").unwrap_or("").to_string(),
                    fields,
                    file_name: opt(r, "file_name").map(String::from),
                    folder: opt_id::<16>(r, "folder")?,
                    content,
                };
                let out = self.write(|v| v.put_secret(&ws, id, &p));
                p.content.zeroize();
                Ok(json!({"id": hex::encode(out?)}))
            }
            "move_secret" => {
                // re-seal the current head with a new folder (a new version)
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: SecretId = arr(s(r, "id")?)?;
                let folder = opt_id::<16>(r, "folder")?;
                self.write(|v| {
                    let st = v.state(&ws)?;
                    let it = st.secrets.get(&id).ok_or_else(|| anyhow!("unknown secret"))?;
                    let mut p = v.open_secret(&st, &id, it.heads()[0])?;
                    p.folder = folder;
                    v.put_secret(&ws, Some(id), &p)?;
                    p.content.zeroize();
                    Ok(json!(null))
                })
            }
            "resolve_conflict" => {
                // keep the chosen head as the next version
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: SecretId = arr(s(r, "id")?)?;
                let entry: [u8; 32] = arr(s(r, "entry")?)?;
                self.write(|v| {
                    let st = v.state(&ws)?;
                    let it = st.secrets.get(&id).ok_or_else(|| anyhow!("unknown secret"))?;
                    let ver = it.heads().into_iter().find(|x| x.entry_id == entry).ok_or_else(|| anyhow!("not a current version"))?;
                    let mut p = v.open_secret(&st, &id, ver)?;
                    v.put_secret(&ws, Some(id), &p)?;
                    p.content.zeroize();
                    Ok(json!(null))
                })
            }
            "delete_secret" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: SecretId = arr(s(r, "id")?)?;
                self.write(|v| v.append(&ws, Op::SecretDelete { secret_id: id }).map(|_| json!(null)))
            }
            "put_folder" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                let id = opt_id::<16>(r, "id")?;
                let p = FolderPayload { name: s(r, "name")?.trim().to_string(), parent: opt_id::<16>(r, "parent")? };
                let fid = self.write(|v| v.put_folder(&ws, id, &p))?;
                Ok(json!({"id": hex::encode(fid)}))
            }
            "delete_folder" => {
                // only empty folders can be deleted (no live secrets or subfolders inside)
                let ws: WsId = arr(s(r, "ws")?)?;
                let id: FolderId = arr(s(r, "id")?)?;
                self.write(|v| {
                    let st = v.state(&ws)?;
                    let tree = v.folder_tree(&st);
                    if tree.values().any(|(_, p)| p == &Some(id)) {
                        bail!("folder is not empty");
                    }
                    for (sid, it) in st.secrets.iter().filter(|(_, it)| !it.deleted) {
                        if v.open_secret(&st, sid, it.heads()[0]).map(|p| p.folder == Some(id)).unwrap_or(false) {
                            bail!("folder is not empty");
                        }
                    }
                    v.append(&ws, Op::FolderDelete { folder_id: id }).map(|_| json!(null))
                })
            }
            "propose_remove" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                let target: Pk = arr(s(r, "member")?)?;
                self.write(|v| v.propose(&ws, Change::Remove { target }).map(|_| json!(null)))
            }
            "approve" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                let p: [u8; 32] = arr(s(r, "proposal")?)?;
                self.write(|v| v.approve(&ws, &p).map(|_| json!(null)))
            }
            "maintain" => {
                let ws: WsId = arr(s(r, "ws")?)?;
                self.write(|v| v.maintain(&ws).map(|n| json!({"fixed": n})))
            }

            // ---- group sync
            "sync_host" => {
                self.stop_all();
                let ws: WsId = arr(s(r, "ws")?)?;
                let minutes = r.get("minutes").and_then(|m| m.as_u64()).unwrap_or(5).clamp(1, 15);
                let h = sync::host(self.vault()?, ws, minutes)?;
                let out = json!({"ticket": h.ticket, "expires": h.exp});
                self.host = Some(h);
                Ok(out)
            }
            "sync_host_status" => {
                let h = self.host.as_ref().ok_or_else(|| anyhow!("no sync session"))?;
                let ws = h.ws;
                // current members (the list changes while a session runs: adds, removals)
                let members = self.read(|v| {
                    let st = v.state(&ws)?;
                    let me = v.identity()?.sign_pk();
                    Ok(st.members.iter().map(|m| json!({"pk": hex::encode(m.sign_pk), "name": m.name, "me": m.sign_pk == me})).collect::<Vec<_>>())
                })?;
                Ok(json!({"ticket": h.ticket, "expires": h.exp, "accepting": h.accepting(), "now": now_ms(), "peers": h.peers(), "members": members}))
            }
            "sync_join" => {
                self.stop_all();
                let j = sync::join(self.vault()?, s(r, "ticket")?)?;
                let st = j.status();
                self.join = Some(j);
                Ok(serde_json::to_value(st)?)
            }
            "sync_join_status" => {
                let j = self.join.as_ref().ok_or_else(|| anyhow!("no sync session"))?;
                Ok(serde_json::to_value(j.status())?)
            }
            "sync_stop" => {
                self.stop_all();
                Ok(json!(null))
            }
            "code_kind" => {
                let t = s(r, "code")?.trim();
                let kind = if t.starts_with(ticket::TICKET_PREFIX) {
                    "sync"
                } else if t.starts_with(ticket::INVITE_PREFIX) {
                    "invite"
                } else {
                    "unknown"
                };
                Ok(json!({"kind": kind}))
            }

            // ---- in-person ceremony (new workspace, or invite into an existing one)
            "ceremony_create" => {
                self.stop_all();
                let existing = opt_id::<16>(r, "ws")?;
                let c = ceremony::create(self.vault()?, opt(r, "name").unwrap_or(""), existing)?;
                let out = json!({"invite": c.invite, "name": c.ws_name, "existing": existing.is_some()});
                self.creator = Some(c);
                Ok(out)
            }
            "ceremony_status" => {
                let c = self.creator.as_ref().ok_or_else(|| anyhow!("no ceremony"))?;
                Ok(serde_json::to_value(c.status())?)
            }
            "ceremony_accept" => {
                let c = self.creator.as_ref().ok_or_else(|| anyhow!("no ceremony"))?;
                c.accept(s(r, "pk")?, r.get("ok").and_then(|b| b.as_bool()).unwrap_or(true))?;
                Ok(serde_json::to_value(c.status())?)
            }
            "ceremony_finish" => {
                let c = self.creator.clone().ok_or_else(|| anyhow!("no ceremony"))?;
                let ws = ceremony::finish(self.vault()?, &c)?;
                Ok(json!({"ws": hex::encode(ws)}))
            }
            "ceremony_join" => {
                self.stop_all();
                let j = ceremony::join(self.vault()?, s(r, "invite")?)?;
                let st = j.status();
                self.cjoin = Some(j);
                Ok(serde_json::to_value(st)?)
            }
            "ceremony_join_status" => {
                let j = self.cjoin.as_ref().ok_or_else(|| anyhow!("no ceremony"))?;
                Ok(serde_json::to_value(j.status())?)
            }
            "ceremony_pick" => {
                let j = self.cjoin.as_ref().ok_or_else(|| anyhow!("no ceremony"))?;
                Ok(json!({"correct": j.pick(s(r, "code")?)}))
            }
            "ceremony_cancel" => {
                self.stop_all();
                Ok(json!(null))
            }

            // ---- stateless helpers
            "addrs" => Ok(json!(crate::net::local_addrs())),
            "set_ifaces" => {
                let names = r
                    .get("names")
                    .and_then(|v| v.as_array())
                    .map(|a| a.iter().filter_map(|x| x.as_str().map(String::from)).collect());
                crate::net::set_usable_ifaces(names);
                Ok(json!(crate::net::local_addrs()))
            }
            "version" => Ok(json!({"core": env!("CARGO_PKG_VERSION"), "vault": crate::store::VAULT_VERSION})),
            other => bail!("unknown command '{other}'"),
        }
    }

    /// Open (or switch to) the vault at `dir` with `key`. The key is copied into the vault and
    /// zeroized when the vault is dropped; callers zeroize their own copy.
    pub fn open_with_key(&mut self, dir: &str, key: &[u8; 32]) -> Result<Value> {
        let v = Vault::open(&PathBuf::from(dir), *key)?;
        let name = v.data.identity.as_ref().map(|i| i.name.clone());
        self.stop_all();
        self.vault = Some(Arc::new(Mutex::new(v)));
        Ok(json!({"has_identity": name.is_some(), "name": name}))
    }

    /// True if `k` is the key of the open vault (constant time). False when locked.
    pub fn key_matches(&self, k: &[u8]) -> bool {
        self.vault
            .as_ref()
            .is_some_and(|v| v.lock().unwrap().key_matches(k))
    }

    /// Copy of the open vault's key, for the platform biometric seal. None when locked.
    pub fn key_copy(&self) -> Option<zeroize::Zeroizing<[u8; 32]>> {
        self.vault.as_ref().map(|v| v.lock().unwrap().key_copy())
    }

    fn stop_all(&mut self) {
        if let Some(h) = self.host.take() {
            h.stop();
        }
        if let Some(j) = self.join.take() {
            j.stop();
        }
        if let Some(c) = self.creator.take() {
            c.cancel();
        }
        if let Some(j) = self.cjoin.take() {
            j.pick("__cancel__");
        }
    }
}

fn ws_summary(v: &Vault, ws: &WsId) -> Result<Value> {
    let st = v.state(ws)?;
    let me = v.identity()?.sign_pk();
    let local = v.data.local.get(ws).cloned().unwrap_or_default();
    let members: Vec<Value> = st
        .members
        .iter()
        .map(|m| json!({"pk": hex::encode(m.sign_pk), "name": m.name, "me": m.sign_pk == me, "last_sync": local.last_sync.get(&m.sign_pk)}))
        .collect();
    let pending = st.pending_member(&me).is_some();
    Ok(json!({
        "id": hex::encode(ws),
        "name": st.name,
        "seal": hex::encode(st.seal()),
        "members": members,
        "secret_count": st.secrets.values().filter(|r| !r.deleted).count(),
        "last_change": st.last_change,
        "can_read": st.can_read(),
        "is_member": st.is_member(&me),
        "pending": pending,
        "removed": st.removed.iter().any(|m| m.sign_pk == me),
        "stale": local.stale,
        "needs_action": st.proposals.iter().any(|p| !p.approvals.contains(&me) && st.is_member(&me)
            && !matches!(&p.change, Change::Remove { target } if target == &me)),
    }))
}

fn workspace_detail(v: &Vault, ws: &WsId) -> Result<Value> {
    let mut sum = ws_summary(v, ws)?;
    let st = v.state(ws)?;
    let me = v.identity()?.sign_pk();
    let tree = v.folder_tree(&st);
    let live_folder = |f: Option<FolderId>| f.filter(|id| tree.contains_key(id));
    let mut folders: Vec<Value> = tree
        .iter()
        .map(|(id, (name, _))| {
            // a parent that vanished or loops makes the folder a root folder
            let path = folder_path(&tree, Some(*id));
            let parent = if path.len() > 1 {
                Some(path[path.len() - 2])
            } else {
                None
            };
            json!({"id": hex::encode(id), "name": name, "parent": parent.map(hex::encode)})
        })
        .collect();
    folders.sort_by(|a, b| {
        a["name"]
            .as_str()
            .map(str::to_lowercase)
            .cmp(&b["name"].as_str().map(str::to_lowercase))
    });
    let mut secrets = vec![];
    for (id, it) in st.secrets.iter().filter(|(_, it)| !it.deleted) {
        let heads = it.heads();
        let meta = v.open_secret(&st, id, heads[0]).ok();
        secrets.push(json!({
            "id": hex::encode(id),
            "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_else(|| "(không giải mã được)".into()),
            "kind": meta.as_ref().map(|m| m.kind.clone()).unwrap_or_default(),
            "fields": meta.as_ref().map(|m| public_fields(&m.fields)).unwrap_or_default(),
            "file_name": meta.as_ref().and_then(|m| m.file_name.clone()),
            "folder": meta.as_ref().and_then(|m| live_folder(m.folder)).map(hex::encode),
            "version": heads[0].version,
            "ts": heads[0].ts,
            "conflict": heads.len() > 1,
        }));
    }
    secrets.sort_by(|a, b| {
        a["name"]
            .as_str()
            .map(str::to_lowercase)
            .cmp(&b["name"].as_str().map(str::to_lowercase))
    });
    sum["secrets"] = Value::Array(secrets);
    sum["folders"] = Value::Array(folders);
    sum["proposals"] = Value::Array(
        st.proposals
            .iter()
            .map(|p| {
                let (kind, who) = match &p.change {
                    Change::Add { member } => ("add", member.name.clone()),
                    Change::Remove { target } => (
                        "remove",
                        st.member(target)
                            .map(|m| m.name.clone())
                            .unwrap_or_default(),
                    ),
                };
                let about_me = match &p.change {
                    Change::Add { member } => member.sign_pk == me,
                    Change::Remove { target } => target == &me,
                };
                json!({"id": hex::encode(p.id), "kind": kind, "name": who,
                    "proposer": st.member(&p.proposer).map(|m| m.name.clone()),
                    "approvals": p.approvals.len(), "needed": st.threshold(&p.change),
                    "approved_by_me": p.approvals.contains(&me), "about_me": about_me,
                    "can_approve": st.is_member(&me) && !about_me && !p.approvals.contains(&me),
                    "needs_keys": p.needs_keys})
            })
            .collect(),
    );
    Ok(sum)
}
