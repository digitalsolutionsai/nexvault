//! The C entry points used by the iOS Face ID / Touch ID path (the Android path uses JNI).

use std::ffi::{CStr, CString};

use nexvault_core::ffi::{nv_call, nv_check_key, nv_free, nv_master_for_seal, nv_open_with_key};
use serde_json::{json, Value};

fn call(req: Value) -> Value {
    let r = CString::new(req.to_string()).unwrap();
    unsafe {
        let p = nv_call(r.as_ptr());
        let v: Value = serde_json::from_str(CStr::from_ptr(p).to_str().unwrap()).unwrap();
        nv_free(p);
        v
    }
}

#[test]
fn ios_biometric_path_moves_the_key_without_json() {
    let tmp = std::env::temp_dir().join(format!("nv-ffi-{}", std::process::id()));
    let dir = tmp.to_str().unwrap();
    let mut k = [0u8; 32];
    // locked: nothing to seal
    assert_eq!(unsafe { nv_master_for_seal(k.as_mut_ptr()) }, 0);

    assert_eq!(
        call(json!({"cmd": "pin_setup", "dir": dir, "pin": "123456"}))["ok"],
        true
    );
    // writes vault.bin, so a wrong key below must fail to decrypt it
    assert_eq!(
        call(json!({"cmd": "create_identity", "name": "An"}))["ok"],
        true
    );
    assert_eq!(unsafe { nv_master_for_seal(k.as_mut_ptr()) }, 1);
    assert_ne!(k, [0u8; 32]);
    assert_eq!(unsafe { nv_check_key(k.as_ptr(), 32) }, 1);
    let mut wrong = k;
    wrong[0] ^= 1;
    assert_eq!(unsafe { nv_check_key(wrong.as_ptr(), 32) }, 0);
    assert_eq!(unsafe { nv_check_key(k.as_ptr(), 31) }, 0);

    // lock, then open with the sealed key as the Face ID path does
    call(json!({"cmd": "lock"}));
    let d = CString::new(dir).unwrap();
    let open = |key: &[u8; 32]| unsafe {
        let p = nv_open_with_key(d.as_ptr(), key.as_ptr(), 32);
        let v: Value = serde_json::from_str(CStr::from_ptr(p).to_str().unwrap()).unwrap();
        nv_free(p);
        v
    };
    assert_eq!(open(&wrong)["ok"], false);
    assert_eq!(open(&k)["ok"], true);
    assert_eq!(unsafe { nv_check_key(k.as_ptr(), 32) }, 1);
    let _ = std::fs::remove_dir_all(&tmp);
}
