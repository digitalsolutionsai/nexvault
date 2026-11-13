//! End-to-end over real TCP sockets.

use std::time::{Duration, Instant};

use nexvault_core::api::Api;
use serde_json::{json, Value};

fn call(api: &mut Api, v: Value) -> Value {
    let out: Value = serde_json::from_str(&api.call(&v.to_string())).unwrap();
    assert_eq!(out["ok"], true, "{v} -> {out}");
    out["data"].clone()
}

fn call_err(api: &mut Api, v: Value) -> String {
    let out: Value = serde_json::from_str(&api.call(&v.to_string())).unwrap();
    assert_eq!(out["ok"], false, "expected failure for {v}, got {out}");
    out["error"].as_str().unwrap().to_string()
}

fn wait<F: FnMut() -> bool>(what: &str, mut f: F) {
    let t = Instant::now();
    while !f() {
        assert!(
            t.elapsed() < Duration::from_secs(25),
            "timed out waiting for {what}"
        );
        std::thread::sleep(Duration::from_millis(50));
    }
}

fn tmpdir(tag: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("nv-test-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

fn device(name: &str, tmp: &std::path::Path) -> Api {
    let mut a = Api::default();
    let key = hex::encode(nexvault_core::crypto::random::<32>());
    call(
        &mut a,
        json!({"cmd": "open", "dir": tmp.join(name), "key": key}),
    );
    call(&mut a, json!({"cmd": "create_identity", "name": name}));
    a
}

fn pk(a: &mut Api) -> String {
    call(a, json!({"cmd": "me"}))["pk"]
        .as_str()
        .unwrap()
        .to_string()
}

fn ws_of(a: &mut Api, ws: &str) -> Value {
    call(a, json!({"cmd": "workspace", "ws": ws}))
}

/// In-person ceremony. `ws` = Some(id) invites into an existing workspace.
fn ceremony(creator: &mut Api, joiners: &mut [&mut Api], name: &str, ws: Option<&str>) -> String {
    let mut req = json!({"cmd": "ceremony_create", "name": name});
    if let Some(w) = ws {
        req["ws"] = json!(w);
    }
    let invite = call(creator, req)["invite"].as_str().unwrap().to_string();
    for (i, j) in joiners.iter_mut().enumerate() {
        call(j, json!({"cmd": "ceremony_join", "invite": invite}));
        wait("verify screen", || {
            call(j, json!({"cmd": "ceremony_join_status"}))["state"] == "verify"
        });
        let st = call(j, json!({"cmd": "ceremony_join_status"}));
        wait("creator sees joiner", || {
            call(creator, json!({"cmd": "ceremony_status"}))["joiners"]
                .as_array()
                .unwrap()
                .len()
                > i
        });
        let jv = call(creator, json!({"cmd": "ceremony_status"}))["joiners"][i].clone();
        assert_eq!(
            jv["seal"], st["seal"],
            "both screens must show the same seal"
        );
        let code = jv["code"].as_str().unwrap();
        assert_eq!(
            call(j, json!({"cmd": "ceremony_pick", "code": code}))["correct"],
            true
        );
        wait("joiner verified", || {
            call(creator, json!({"cmd": "ceremony_status"}))["joiners"][i]["verified"] == true
        });
        call(creator, json!({"cmd": "ceremony_accept", "pk": jv["pk"]}));
    }
    let id = call(creator, json!({"cmd": "ceremony_finish"}))["ws"]
        .as_str()
        .unwrap()
        .to_string();
    for j in joiners.iter_mut() {
        wait("joiner done", || {
            call(j, json!({"cmd": "ceremony_join_status"}))["state"] == "done"
        });
    }
    id
}

/// Host + joiners sync until every listed device has the same version vector.
fn group_sync(host: &mut Api, joiners: &mut [&mut Api], ws: &str) {
    let t = call(host, json!({"cmd": "sync_host", "ws": ws}))["ticket"]
        .as_str()
        .unwrap()
        .to_string();
    for j in joiners.iter_mut() {
        call(j, json!({"cmd": "sync_join", "ticket": t}));
    }
    let n = joiners.len();
    wait("all peers in sync", || {
        let p = call(host, json!({"cmd": "sync_host_status"}))["peers"].clone();
        p.as_array()
            .unwrap()
            .iter()
            .filter(|x| x["state"] == "done")
            .count()
            >= n
    });
    for j in joiners.iter_mut() {
        wait("joiner done", || {
            call(j, json!({"cmd": "sync_join_status"}))["state"] == "done"
        });
        call(j, json!({"cmd": "sync_stop"}));
    }
    call(host, json!({"cmd": "sync_stop"}));
}

#[test]
fn founders_secrets_folders_and_sync() {
    let tmp = tmpdir("flow");
    let mut an = device("An", &tmp);
    let mut minh = device("Minh", &tmp);
    let mut ha = device("Hà", &tmp);
    let mut eve = device("Eve", &tmp);

    let ws = ceremony(&mut an, &mut [&mut minh, &mut ha], "Founders", None);
    for d in [&mut an, &mut minh, &mut ha] {
        let w = ws_of(d, &ws);
        assert_eq!(w["members"].as_array().unwrap().len(), 3);
        assert_eq!(w["can_read"], true);
    }
    assert_eq!(ws_of(&mut ha, &ws)["seal"], ws_of(&mut an, &ws)["seal"]);

    // folders: iOS / Production
    let ios = call(
        &mut an,
        json!({"cmd": "put_folder", "ws": ws, "name": "iOS"}),
    )["id"]
        .as_str()
        .unwrap()
        .to_string();
    let prod = call(
        &mut an,
        json!({"cmd": "put_folder", "ws": ws, "name": "Production", "parent": ios}),
    )["id"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(call_err(
        &mut an,
        json!({"cmd": "put_folder", "ws": ws, "id": ios, "name": "iOS", "parent": prod})
    )
    .contains("into itself"));

    let p8 = "-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49\n-----END PRIVATE KEY-----";
    let s1 = call(&mut an, json!({"cmd": "put_secret", "ws": ws, "name": "APNs production", "kind": "p8", "folder": prod,
        "fields": [["Key ID", "7XK2P9QM4D"], ["*Mật khẩu", "hunter2"]], "file_name": "AuthKey_7XK2P9QM4D.p8", "text": p8}))["id"]
        .as_str().unwrap().to_string();
    call(
        &mut minh,
        json!({"cmd": "put_secret", "ws": ws, "name": "Stripe live", "kind": "env", "text": "STRIPE_KEY=sk_live_x"}),
    );

    group_sync(&mut ha, &mut [&mut an, &mut minh], &ws);
    for d in [&mut an, &mut minh, &mut ha] {
        let w = ws_of(d, &ws);
        assert_eq!(w["secret_count"], 2);
        assert_eq!(w["folders"].as_array().unwrap().len(), 2);
        let apns = w["secrets"]
            .as_array()
            .unwrap()
            .iter()
            .find(|s| s["name"] == "APNs production")
            .unwrap()
            .clone();
        assert_eq!(apns["folder"], prod.as_str());
        assert_eq!(
            apns["fields"][1][1], "",
            "secret field must not leak outside reveal"
        );
    }
    assert!(call_err(
        &mut minh,
        json!({"cmd": "delete_folder", "ws": ws, "id": ios})
    )
    .contains("not empty"));

    let r = call(&mut minh, json!({"cmd": "reveal", "ws": ws, "id": s1}));
    assert_eq!(r["text"], p8);
    assert_eq!(r["secret_fields"][0][1], "hunter2");
    let meta = call(&mut minh, json!({"cmd": "secret", "ws": ws, "id": s1}));
    assert!(meta["history"]
        .as_array()
        .unwrap()
        .iter()
        .any(|h| h["who"] == "Minh" && h["action"] == "viewed"));

    // move to root, then the empty folders can go
    call(
        &mut minh,
        json!({"cmd": "move_secret", "ws": ws, "id": s1, "folder": ""}),
    );
    call(
        &mut minh,
        json!({"cmd": "delete_folder", "ws": ws, "id": prod}),
    );
    call(
        &mut minh,
        json!({"cmd": "delete_folder", "ws": ws, "id": ios}),
    );
    assert_eq!(
        ws_of(&mut minh, &ws)["folders"].as_array().unwrap().len(),
        0
    );

    // an outsider cannot even decrypt a ticket
    let t = call(&mut ha, json!({"cmd": "sync_host", "ws": ws}))["ticket"]
        .as_str()
        .unwrap()
        .to_string();
    let e = call_err(&mut eve, json!({"cmd": "sync_join", "ticket": t}));
    assert!(e.contains("not in") || e.contains("not for"), "{e}");
    call(&mut ha, json!({"cmd": "sync_stop"}));
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn concurrent_edits_are_kept_and_resolved() {
    let tmp = tmpdir("conflict");
    let mut a = device("A", &tmp);
    let mut b = device("B", &tmp);
    let ws = ceremony(&mut a, &mut [&mut b], "W", None);
    let id = call(
        &mut a,
        json!({"cmd": "put_secret", "ws": ws, "name": "DB", "text": "v1"}),
    )["id"]
        .as_str()
        .unwrap()
        .to_string();
    group_sync(&mut a, &mut [&mut b], &ws);
    call(
        &mut a,
        json!({"cmd": "put_secret", "ws": ws, "id": id, "name": "DB", "text": "from-a"}),
    );
    call(
        &mut b,
        json!({"cmd": "put_secret", "ws": ws, "id": id, "name": "DB", "text": "from-b"}),
    );
    group_sync(&mut a, &mut [&mut b], &ws);
    let m = call(&mut b, json!({"cmd": "secret", "ws": ws, "id": id}));
    assert_eq!(m["conflict"], true);
    let versions = m["versions"].as_array().unwrap().clone();
    assert_eq!(versions.len(), 2);
    let from_a = versions.iter().find(|v| v["who"] == "A").unwrap()["entry"]
        .as_str()
        .unwrap()
        .to_string();
    assert_eq!(
        call(
            &mut b,
            json!({"cmd": "reveal", "ws": ws, "id": id, "entry": from_a})
        )["text"],
        "from-a"
    );
    call(
        &mut b,
        json!({"cmd": "resolve_conflict", "ws": ws, "id": id, "entry": from_a}),
    );
    group_sync(&mut b, &mut [&mut a], &ws);
    for d in [&mut a, &mut b] {
        assert_eq!(
            call(d, json!({"cmd": "secret", "ws": ws, "id": id}))["conflict"],
            false
        );
        assert_eq!(
            call(d, json!({"cmd": "reveal", "ws": ws, "id": id}))["text"],
            "from-a"
        );
    }
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn add_and_remove_members() {
    let tmp = tmpdir("members");
    let mut an = device("An", &tmp);
    let mut minh = device("Minh", &tmp);
    let mut ha = device("Hà", &tmp);
    let mut tuan = device("Tuấn", &tmp);
    let ws = ceremony(&mut an, &mut [&mut minh, &mut ha], "Founders", None);
    let old = call(
        &mut an,
        json!({"cmd": "put_secret", "ws": ws, "name": "Old key", "text": "before-tuan"}),
    )["id"]
        .as_str()
        .unwrap()
        .to_string();

    // An meets Tuấn in person: Add proposal (An's vote), Tuấn waits for the others
    let same = ceremony(&mut an, &mut [&mut tuan], "", Some(&ws));
    assert_eq!(same, ws);
    let tw = ws_of(&mut tuan, &ws);
    assert_eq!(tw["pending"], true);
    assert_eq!(tw["can_read"], false);
    // Minh and Hà approve concurrently, each unaware of the other: nobody attaches keys
    group_sync(&mut an, &mut [&mut minh, &mut ha], &ws);
    let pid = ws_of(&mut minh, &ws)["proposals"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    call(
        &mut minh,
        json!({"cmd": "approve", "ws": ws, "proposal": pid}),
    );
    call(
        &mut ha,
        json!({"cmd": "approve", "ws": ws, "proposal": pid}),
    );
    group_sync(&mut an, &mut [&mut minh, &mut ha], &ws);
    assert_eq!(ws_of(&mut an, &ws)["proposals"][0]["needs_keys"], true);
    // maintain() supplies the keys
    assert_eq!(
        call(&mut an, json!({"cmd": "maintain", "ws": ws}))["fixed"],
        1
    );
    // the pending newcomer can read the ticket and is admitted by the host
    group_sync(&mut an, &mut [&mut tuan, &mut minh, &mut ha], &ws);
    let tw = ws_of(&mut tuan, &ws);
    assert_eq!(tw["is_member"], true);
    assert_eq!(tw["can_read"], true);
    assert_eq!(
        call(&mut tuan, json!({"cmd": "reveal", "ws": ws, "id": old}))["text"],
        "before-tuan"
    );

    // remove Minh: 3 stay -> needs 2. An proposes, Hà approves (and attaches the new key)
    let minh_pk = pk(&mut minh);
    call(
        &mut an,
        json!({"cmd": "propose_remove", "ws": ws, "member": minh_pk}),
    );
    group_sync(&mut an, &mut [&mut ha], &ws);
    let pid = ws_of(&mut ha, &ws)["proposals"][0]["id"]
        .as_str()
        .unwrap()
        .to_string();
    assert_eq!(ws_of(&mut ha, &ws)["proposals"][0]["needed"], 2);
    call(
        &mut ha,
        json!({"cmd": "approve", "ws": ws, "proposal": pid}),
    );
    assert_eq!(ws_of(&mut ha, &ws)["members"].as_array().unwrap().len(), 3);
    let fresh = call(
        &mut ha,
        json!({"cmd": "put_secret", "ws": ws, "name": "New", "text": "after-removal"}),
    )["id"]
        .as_str()
        .unwrap()
        .to_string();

    // Minh is refused by the host even though he can still decrypt the ticket
    let t = call(&mut ha, json!({"cmd": "sync_host", "ws": ws}))["ticket"]
        .as_str()
        .unwrap()
        .to_string();
    call(&mut minh, json!({"cmd": "sync_join", "ticket": t}));
    wait("Minh refused", || {
        let s = call(&mut minh, json!({"cmd": "sync_join_status"}));
        s["state"] == "error" || s["state"] == "closed"
    });
    let err = call(&mut minh, json!({"cmd": "sync_join_status"}))["error"]
        .as_str()
        .unwrap_or_default()
        .to_string();
    assert!(err.contains("removed"), "{err}");
    let hs = call(&mut ha, json!({"cmd": "sync_host_status"}));
    assert!(
        hs["peers"]
            .as_array()
            .unwrap()
            .iter()
            .any(|p| p["state"] == "removed" && p["name"] == "Minh"),
        "{hs}"
    );
    assert_eq!(hs["members"].as_array().unwrap().len(), 3);
    call(&mut minh, json!({"cmd": "sync_stop"}));
    call(&mut ha, json!({"cmd": "sync_stop"}));
    // the others get the new key and the new secret
    group_sync(&mut ha, &mut [&mut an, &mut tuan], &ws);
    for d in [&mut an, &mut tuan] {
        assert_eq!(
            call(d, json!({"cmd": "reveal", "ws": ws, "id": fresh}))["text"],
            "after-removal"
        );
    }
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn wrong_code_aborts_ceremony() {
    let tmp = tmpdir("abort");
    let mut a = device("A", &tmp);
    let mut b = device("B", &tmp);
    let invite = call(&mut a, json!({"cmd": "ceremony_create", "name": "X"}))["invite"]
        .as_str()
        .unwrap()
        .to_string();
    call(&mut b, json!({"cmd": "ceremony_join", "invite": invite}));
    wait("verify", || {
        call(&mut b, json!({"cmd": "ceremony_join_status"}))["state"] == "verify"
    });
    wait("creator sees", || {
        !call(&mut a, json!({"cmd": "ceremony_status"}))["joiners"]
            .as_array()
            .unwrap()
            .is_empty()
    });
    let code = call(&mut a, json!({"cmd": "ceremony_status"}))["joiners"][0]["code"]
        .as_str()
        .unwrap()
        .to_string();
    let wrong = call(&mut b, json!({"cmd": "ceremony_join_status"}))["choices"]
        .as_array()
        .unwrap()
        .iter()
        .find(|c| c.as_str() != Some(&code))
        .unwrap()
        .as_str()
        .unwrap()
        .to_string();
    assert_eq!(
        call(&mut b, json!({"cmd": "ceremony_pick", "code": wrong}))["correct"],
        false
    );
    wait("creator sees failure", || {
        call(&mut a, json!({"cmd": "ceremony_status"}))["joiners"][0]["failed"] == true
    });
    let pk = call(&mut a, json!({"cmd": "ceremony_status"}))["joiners"][0]["pk"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(
        call_err(&mut a, json!({"cmd": "ceremony_accept", "pk": pk})).contains("not confirmed")
    );
    assert!(call_err(&mut a, json!({"cmd": "ceremony_finish"})).contains("at least one"));
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn vault_key_backup_and_corruption() {
    let tmp = tmpdir("vault");
    let key = hex::encode([7u8; 32]);
    let mut a = Api::default();
    call(
        &mut a,
        json!({"cmd": "open", "dir": tmp.join("a"), "key": key}),
    );
    call(&mut a, json!({"cmd": "create_identity", "name": "A"}));
    let a_pk = pk(&mut a);
    // wrong key
    let e = call_err(
        &mut Api::default(),
        json!({"cmd": "open", "dir": tmp.join("a"), "key": hex::encode([8u8; 32])}),
    );
    assert!(e.contains("wrong master key"), "{e}");
    // the previous good copy (vault.bak, kept on every save) is used when vault.bin is torn
    std::fs::copy(tmp.join("a/vault.bin"), tmp.join("a/vault.bak")).unwrap();
    let _ = std::fs::write(tmp.join("a/vault.bin"), b"garbage");
    let mut c = Api::default();
    assert_eq!(
        call(
            &mut c,
            json!({"cmd": "open", "dir": tmp.join("a"), "key": key})
        )["name"],
        "A"
    );
    // passphrase backup restores identity on a fresh device
    assert!(call_err(
        &mut c,
        json!({"cmd": "backup_export", "passphrase": "short"})
    )
    .contains("10 characters"));
    let b64 = call(
        &mut c,
        json!({"cmd": "backup_export", "passphrase": "correct horse battery"}),
    )["b64"]
        .as_str()
        .unwrap()
        .to_string();
    let mut d = Api::default();
    call(
        &mut d,
        json!({"cmd": "open", "dir": tmp.join("d"), "key": hex::encode([9u8; 32])}),
    );
    assert!(call_err(
        &mut d,
        json!({"cmd": "backup_import", "b64": b64, "passphrase": "wrong passphrase!"})
    )
    .contains("wrong passphrase"));
    call(
        &mut d,
        json!({"cmd": "backup_import", "b64": b64, "passphrase": "correct horse battery"}),
    );
    assert_eq!(pk(&mut d), a_pk);
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn pin_custody_keeps_the_key_in_the_core() {
    let tmp = std::env::temp_dir().join(format!("nv-pin-{}", std::process::id()));
    let dir = tmp.to_str().unwrap();
    let mut a = Api::default();
    let blob = call(
        &mut a,
        json!({"cmd": "pin_setup", "dir": dir, "pin": "123456"}),
    )["blob"]
        .as_str()
        .unwrap()
        .to_string();
    // no response ever carries the key
    assert!(!blob.is_empty());
    call(&mut a, json!({"cmd": "create_identity", "name": "An"}));
    call(
        &mut a,
        json!({"cmd": "pin_check", "pin": "123456", "blob": blob}),
    );
    assert!(call_err(
        &mut a,
        json!({"cmd": "pin_check", "pin": "123457", "blob": blob})
    )
    .contains("wrong PIN"));

    // change PIN, then reopen from scratch with the new one
    let blob2 = call(
        &mut a,
        json!({"cmd": "pin_change", "blob": blob, "old": "123456", "new": "654321"}),
    )["blob"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(call_err(
        &mut a,
        json!({"cmd": "pin_change", "blob": blob, "old": "000000", "new": "1"})
    )
    .contains("wrong PIN"));
    call(&mut a, json!({"cmd": "lock"}));
    let mut b = Api::default();
    assert!(call_err(
        &mut b,
        json!({"cmd": "pin_open", "dir": dir, "pin": "123456", "blob": blob2})
    )
    .contains("wrong PIN"));
    assert_eq!(
        call(
            &mut b,
            json!({"cmd": "pin_open", "dir": dir, "pin": "654321", "blob": blob2})
        )["name"],
        "An"
    );
    // a PIN blob from another vault does not pass re-authentication here
    let other = std::env::temp_dir().join(format!("nv-pin-o-{}", std::process::id()));
    let mut c = Api::default();
    let blob_o = call(
        &mut c,
        json!({"cmd": "pin_setup", "dir": other.to_str().unwrap(), "pin": "111111"}),
    )["blob"]
        .as_str()
        .unwrap()
        .to_string();
    assert!(call_err(
        &mut b,
        json!({"cmd": "pin_check", "pin": "111111", "blob": blob_o})
    )
    .contains("wrong PIN"));
    let _ = std::fs::remove_dir_all(&tmp);
    let _ = std::fs::remove_dir_all(&other);
}

#[test]
fn restored_device_must_sync_before_writing() {
    let tmp = tmpdir("restore");
    let mut a = device("A", &tmp);
    let mut b = device("B", &tmp);
    let ws = ceremony(&mut a, &mut [&mut b], "W", None);
    let b64 = call(
        &mut a,
        json!({"cmd": "backup_export", "passphrase": "correct horse battery"}),
    )["b64"]
        .as_str()
        .unwrap()
        .to_string();
    // A keeps working after the backup, and B receives it
    call(
        &mut a,
        json!({"cmd": "put_secret", "ws": ws, "name": "after backup", "text": "x"}),
    );
    group_sync(&mut a, &mut [&mut b], &ws);
    // A's phone is lost; restore the older backup on a new phone
    let mut a2 = Api::default();
    call(
        &mut a2,
        json!({"cmd": "open", "dir": tmp.join("a2"), "key": hex::encode([5u8; 32])}),
    );
    call(
        &mut a2,
        json!({"cmd": "backup_import", "b64": b64, "passphrase": "correct horse battery"}),
    );
    assert_eq!(ws_of(&mut a2, &ws)["stale"], true);
    let e = call_err(
        &mut a2,
        json!({"cmd": "put_secret", "ws": ws, "name": "too early", "text": "y"}),
    );
    assert!(e.contains("sync with a member"), "{e}");
    // after one sync it has its own later entries back and may write again without reusing seq
    group_sync(&mut b, &mut [&mut a2], &ws);
    assert_eq!(ws_of(&mut a2, &ws)["stale"], false);
    assert_eq!(ws_of(&mut a2, &ws)["secret_count"], 1);
    call(
        &mut a2,
        json!({"cmd": "put_secret", "ws": ws, "name": "new phone", "text": "z"}),
    );
    group_sync(&mut a2, &mut [&mut b], &ws);
    assert_eq!(ws_of(&mut b, &ws)["secret_count"], 2);
    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn device_custody_with_recovery_code() {
    let tmp = std::env::temp_dir().join(format!("nv-dev-{}", std::process::id()));
    let dir = tmp.to_str().unwrap();
    let mut a = Api::default();
    call(&mut a, json!({"cmd": "device_setup", "dir": dir}));
    call(&mut a, json!({"cmd": "create_identity", "name": "An"}));
    let r = call(&mut a, json!({"cmd": "recovery_new"}));
    let code = r["code"].as_str().unwrap().to_string();
    let blob = r["blob"].as_str().unwrap().to_string();
    assert_eq!(code.len(), 29);
    assert_eq!(code.matches('-').count(), 5);
    assert!(!code.contains(['I', 'L', 'O', 'U']));

    // the user types it back sloppily: lowercase, spaces, O for 0
    call(&mut a, json!({"cmd": "lock"}));
    let typed = code.to_lowercase().replace('-', " ").replace('0', "o");
    let opened = call(
        &mut a,
        json!({"cmd": "recovery_open", "dir": dir, "code": typed, "blob": blob}),
    );
    assert_eq!(opened["name"], "An");

    call(&mut a, json!({"cmd": "lock"}));
    let mut wrong = code.clone();
    wrong.replace_range(0..1, if code.starts_with('7') { "8" } else { "7" });
    assert!(call_err(
        &mut a,
        json!({"cmd": "recovery_open", "dir": dir, "code": wrong, "blob": blob})
    )
    .contains("wrong recovery code"));
    // a new code replaces the old one only in the sense that the caller stores the new blob
    call(
        &mut a,
        json!({"cmd": "recovery_open", "dir": dir, "code": code, "blob": blob}),
    );
    let r2 = call(&mut a, json!({"cmd": "recovery_new"}));
    assert_ne!(r2["code"], json!(code));
    let _ = std::fs::remove_dir_all(&tmp);
}
