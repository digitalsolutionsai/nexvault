//! C ABI for Flutter (dart:ffi): one JSON-in / JSON-out entry point.

use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use crate::api::Api;

pub(crate) static API: Mutex<Option<Api>> = Mutex::new(None);

/// Run `f` on the process-wide API instance (shared by dart:ffi and the Android JNI entry points).
pub(crate) fn with_api<R>(f: impl FnOnce(&mut Api) -> R) -> R {
    let mut g = API.lock().unwrap_or_else(|e| e.into_inner());
    f(g.get_or_insert_with(Api::default))
}

/// On iOS the core is linked statically into the app and Dart finds these two by name at run
/// time (dlsym). Nothing in the app calls them directly, so the linker's dead-code stripping
/// would drop them from release builds; `#[used]` marks these references no-dead-strip.
#[used]
static KEEP_FOR_DART: [unsafe extern "C" fn(*const c_char) -> *mut c_char; 1] = [nv_call];
#[used]
static KEEP_FOR_DART_FREE: [unsafe extern "C" fn(*mut c_char); 1] = [nv_free];

/// # Safety
/// `req` must be a valid NUL-terminated UTF-8 string. Free the result with `nv_free`.
#[no_mangle]
pub unsafe extern "C" fn nv_call(req: *const c_char) -> *mut c_char {
    let req = if req.is_null() {
        ""
    } else {
        CStr::from_ptr(req).to_str().unwrap_or("")
    };
    let out = std::panic::catch_unwind(|| with_api(|a| a.call(req)))
        .unwrap_or_else(|_| r#"{"ok":false,"error":"internal error"}"#.to_string());
    CString::new(out).unwrap_or_default().into_raw()
}

/// # Safety
/// `p` must come from `nv_call`.
#[no_mangle]
pub unsafe extern "C" fn nv_free(p: *mut c_char) {
    if !p.is_null() {
        drop(CString::from_raw(p));
    }
}

// ---- iOS biometric path ------------------------------------------------------------------
// Same contract as the Android JNI entry points (jni.rs): Swift moves the vault key between
// the Keychain and the core directly, so it never enters Dart. Swift wipes its buffers.

/// Copy the open vault's key into `out` (32 bytes) for sealing. Returns 1, or 0 when locked.
///
/// # Safety
/// `out` must point to 32 writable bytes.
#[no_mangle]
pub unsafe extern "C" fn nv_master_for_seal(out: *mut u8) -> i32 {
    if out.is_null() {
        return 0;
    }
    match with_api(|a| a.key_copy()) {
        Some(k) => {
            std::ptr::copy_nonoverlapping(k.as_ptr(), out, 32);
            1
        }
        None => 0,
    }
}

unsafe fn key_arg(key: *const u8, len: usize) -> Option<zeroize::Zeroizing<[u8; 32]>> {
    if key.is_null() || len != 32 {
        return None;
    }
    let mut k = zeroize::Zeroizing::new([0u8; 32]);
    std::ptr::copy_nonoverlapping(key, k.as_mut_ptr(), 32);
    Some(k)
}

/// Open the vault with a key unsealed after Face ID / Touch ID. Returns the API JSON
/// response (`{ok,data|error}`); free it with `nv_free`.
///
/// # Safety
/// `dir` must be a NUL-terminated UTF-8 string and `key` must point to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn nv_open_with_key(
    dir: *const c_char,
    key: *const u8,
    len: usize,
) -> *mut c_char {
    let dir = if dir.is_null() {
        ""
    } else {
        CStr::from_ptr(dir).to_str().unwrap_or("")
    };
    let resp = match key_arg(key, len) {
        Some(k) => match std::panic::catch_unwind(|| with_api(|a| a.open_with_key(dir, &k))) {
            Ok(Ok(d)) => serde_json::json!({"ok": true, "data": d}),
            Ok(Err(e)) => serde_json::json!({"ok": false, "error": e.to_string()}),
            Err(_) => serde_json::json!({"ok": false, "error": "internal error"}),
        },
        None => serde_json::json!({"ok": false, "error": "bad key"}),
    };
    CString::new(resp.to_string())
        .unwrap_or_default()
        .into_raw()
}

/// Re-authentication: 1 if `key` is the open vault's key, else 0.
///
/// # Safety
/// `key` must point to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn nv_check_key(key: *const u8, len: usize) -> i32 {
    match key_arg(key, len) {
        Some(k) => i32::from(with_api(|a| a.key_matches(&k[..]))),
        None => 0,
    }
}
