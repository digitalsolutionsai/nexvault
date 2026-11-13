//! Log validation against forged, tampered and out-of-order entries.

use nexvault_core::crypto;
use nexvault_core::model::*;
use nexvault_core::store::Identity;

fn genesis(a: &Identity, b: &Identity, ws: WsId) -> Entry {
    let k: [u8; 32] = crypto::random();
    let members = vec![a.member(), b.member()];
    let keys = members
        .iter()
        .map(|m| KeyWrap {
            epoch: 0,
            wrap: crypto::wrap_for(m, &k, &epoch_ctx(&ws, 0)),
        })
        .collect();
    let body = Body {
        ws,
        author: a.sign_pk(),
        seq: 1,
        ts: now_ms(),
        op: Op::Genesis {
            name: "W".into(),
            members,
            keys,
        },
    };
    let mut e = Entry::signed(&body, &a.sign_sk);
    e.sigs.push(Sig {
        by: b.sign_pk(),
        sig: crypto::sign(&b.sign_sk, &e.body),
    });
    e
}

fn op(by: &Identity, ws: WsId, seq: u64) -> Entry {
    let body = Body {
        ws,
        author: by.sign_pk(),
        seq,
        ts: now_ms(),
        op: Op::SecretDelete { secret_id: [1; 16] },
    };
    Entry::signed(&body, &by.sign_sk)
}

#[test]
fn rejects_bad_entries() {
    let (a, b, eve) = (
        Identity::generate("A"),
        Identity::generate("B"),
        Identity::generate("Eve"),
    );
    let ws: WsId = crypto::random();
    let mut log = WsLog {
        ws,
        entries: vec![],
    };

    // genesis missing a founder's co-signature
    let mut g = genesis(&a, &b, ws);
    let full = g.clone();
    g.sigs.pop();
    assert!(log.ingest(g).unwrap_err().to_string().contains("co-signed"));
    // entries before genesis
    assert!(log.ingest(op(&a, ws, 2)).is_err());
    assert!(log.ingest(full).unwrap());

    // outsider
    assert!(log
        .ingest(op(&eve, ws, 1))
        .unwrap_err()
        .to_string()
        .contains("not a member"));
    // forged: Eve signs an entry claiming to be B
    let body = Body {
        ws,
        author: b.sign_pk(),
        seq: 1,
        ts: now_ms(),
        op: Op::SecretDelete { secret_id: [1; 16] },
    };
    let mut forged = Entry::signed(&body, &eve.sign_sk);
    forged.sigs[0].by = b.sign_pk();
    assert!(log
        .ingest(forged)
        .unwrap_err()
        .to_string()
        .contains("signature"));
    // tampered body
    let mut t = op(&b, ws, 1);
    let last = t.body.len() - 1;
    t.body[last] ^= 1;
    assert!(log.ingest(t).is_err());
    // gap in sequence, then in order, then duplicate
    assert!(log
        .ingest(op(&b, ws, 2))
        .unwrap_err()
        .to_string()
        .contains("gap"));
    assert!(log.ingest(op(&b, ws, 1)).unwrap());
    assert!(!log.ingest(op(&b, ws, 1)).unwrap());
    // another workspace
    assert!(log.ingest(op(&b, crypto::random(), 2)).is_err());
}

#[test]
fn fold_is_order_independent() {
    let (a, b) = (Identity::generate("A"), Identity::generate("B"));
    let ws: WsId = crypto::random();
    let mut x = WsLog {
        ws,
        entries: vec![],
    };
    x.ingest(genesis(&a, &b, ws)).unwrap();
    let g = x.entries[0].clone();
    let ea: Vec<Entry> = (1..=3).map(|i| op(&a, ws, i + 1)).collect();
    let eb: Vec<Entry> = (1..=3).map(|i| op(&b, ws, i)).collect();
    let mut y = WsLog {
        ws,
        entries: vec![g],
    };
    for e in ea.iter().chain(eb.iter()) {
        x.ingest(e.clone()).unwrap();
    }
    for e in eb.iter().chain(ea.iter()) {
        y.ingest(e.clone()).unwrap();
    }
    let (sx, sy) = (
        x.fold(Some((&a.sign_pk(), &a.dh_sk))),
        y.fold(Some((&a.sign_pk(), &a.dh_sk))),
    );
    assert_eq!(sx.last_change, sy.last_change);
    assert_eq!(sx.current, sy.current);
    assert_eq!(x.vv(), y.vv());
}
