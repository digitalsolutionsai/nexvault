//! Android JNI entry points for the biometric path, so the vault key goes
//! Keystore cipher -> Kotlin ByteArray -> Rust and never through Dart (whose strings are
//! immutable and cannot be wiped). Kotlin zero-fills its arrays right after each call.
//!
//! Kotlin side: `object NativeCore` in MainActivity.kt.

use jni::objects::{JByteArray, JClass, JString};
use jni::sys::{jboolean, jbyteArray, jstring, JNI_FALSE, JNI_TRUE};
use jni::JNIEnv;
use serde_json::json;
use zeroize::Zeroize;

use crate::ffi::with_api;

fn key_from(env: &mut JNIEnv, arr: &JByteArray) -> Option<[u8; 32]> {
    let mut v = env.convert_byte_array(arr).ok()?;
    let out: Option<[u8; 32]> = match v.len() {
        32 => v.as_slice().try_into().ok(),
        // seals made by app builds before 2026-11 hold the key as 64 hex characters
        64 => {
            let mut k = [0u8; 32];
            hex::decode_to_slice(&v, &mut k).ok().map(|_| k)
        }
        _ => None,
    };
    v.zeroize();
    out
}

/// Copy of the open vault key, to be sealed by the biometric Keystore key. null when locked.
#[no_mangle]
pub extern "system" fn Java_app_nexvault_nexvault_NativeCore_masterForSeal(
    env: JNIEnv,
    _c: JClass,
) -> jbyteArray {
    let Some(k) = with_api(|a| a.key_copy()) else {
        return std::ptr::null_mut();
    };
    env.byte_array_from_slice(k.as_slice())
        .map(|a| a.into_raw())
        .unwrap_or(std::ptr::null_mut())
}

/// Open the vault with a key unsealed by the biometric prompt. Returns the API JSON response.
#[no_mangle]
pub extern "system" fn Java_app_nexvault_nexvault_NativeCore_openWithKey(
    mut env: JNIEnv,
    _c: JClass,
    dir: JString,
    key: JByteArray,
) -> jstring {
    let dir: String = env.get_string(&dir).map(|s| s.into()).unwrap_or_default();
    let resp = match key_from(&mut env, &key) {
        Some(mut k) => {
            let r = with_api(|a| a.open_with_key(&dir, &k));
            k.zeroize();
            match r {
                Ok(d) => json!({"ok": true, "data": d}),
                Err(e) => json!({"ok": false, "error": e.to_string()}),
            }
        }
        None => json!({"ok": false, "error": "bad key"}),
    };
    env.new_string(resp.to_string())
        .map(|s| s.into_raw())
        .unwrap_or(std::ptr::null_mut())
}

/// Re-authentication: true if the unsealed key is the open vault's key.
#[no_mangle]
pub extern "system" fn Java_app_nexvault_nexvault_NativeCore_checkKey(
    mut env: JNIEnv,
    _c: JClass,
    key: JByteArray,
) -> jboolean {
    match key_from(&mut env, &key) {
        Some(mut k) => {
            let ok = with_api(|a| a.key_matches(&k));
            k.zeroize();
            if ok {
                JNI_TRUE
            } else {
                JNI_FALSE
            }
        }
        None => JNI_FALSE,
    }
}
