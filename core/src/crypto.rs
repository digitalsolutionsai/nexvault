//! Small, explicit crypto helpers. Everything else in the crate goes through these.

use anyhow::{anyhow, Result};
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, XChaCha20Poly1305};
use ed25519_dalek::{Signer, SigningKey, Verifier, VerifyingKey};
use hkdf::Hkdf;
use rand::rngs::OsRng;
use rand::RngCore;
use sha2::Sha256;
use x25519_dalek::{PublicKey as XPublic, StaticSecret};
use zeroize::Zeroize;

use crate::model::{Member, Pk, Wrap};

pub fn random<const N: usize>() -> [u8; N] {
    let mut b = [0u8; N];
    OsRng.fill_bytes(&mut b);
    b
}

pub fn hkdf32(ikm: &[u8], info: &[u8]) -> [u8; 32] {
    let mut out = [0u8; 32];
    Hkdf::<Sha256>::new(Some(b"nexvault/v1"), ikm)
        .expand(info, &mut out)
        .expect("32 bytes is a valid HKDF length");
    out
}

pub fn hash(data: &[u8]) -> [u8; 32] {
    *blake3::hash(data).as_bytes()
}

pub fn sign(sk: &[u8; 32], msg: &[u8]) -> Vec<u8> {
    SigningKey::from_bytes(sk).sign(msg).to_bytes().to_vec()
}

pub fn verify(pk: &Pk, msg: &[u8], sig: &[u8]) -> bool {
    let Ok(vk) = VerifyingKey::from_bytes(pk) else {
        return false;
    };
    let Ok(sig) = ed25519_dalek::Signature::from_slice(sig) else {
        return false;
    };
    vk.verify(msg, &sig).is_ok()
}

pub fn sign_pk(sk: &[u8; 32]) -> Pk {
    SigningKey::from_bytes(sk).verifying_key().to_bytes()
}

pub fn dh_pk(sk: &[u8; 32]) -> Pk {
    XPublic::from(&StaticSecret::from(*sk)).to_bytes()
}

/// XChaCha20-Poly1305 with a random 24-byte nonce. Returns (nonce, ciphertext).
pub fn seal(key: &[u8; 32], aad: &[u8], pt: &[u8]) -> (Vec<u8>, Vec<u8>) {
    let nonce: [u8; 24] = random();
    let ct = XChaCha20Poly1305::new(key.into())
        .encrypt((&nonce).into(), Payload { msg: pt, aad })
        .expect("encryption cannot fail for in-memory buffers");
    (nonce.to_vec(), ct)
}

pub fn open(key: &[u8; 32], nonce: &[u8], aad: &[u8], ct: &[u8]) -> Result<Vec<u8>> {
    if nonce.len() != 24 {
        return Err(anyhow!("bad nonce length"));
    }
    XChaCha20Poly1305::new(key.into())
        .decrypt(nonce.into(), Payload { msg: ct, aad })
        .map_err(|_| anyhow!("decryption failed (wrong key or tampered data)"))
}

/// Wrap a 32-byte epoch secret for one member: ephemeral X25519 -> HKDF -> ChaCha20-Poly1305.
/// `ctx` binds the wrap to a workspace and epoch so it cannot be replayed elsewhere.
pub fn wrap_for(to: &Member, secret: &[u8; 32], ctx: &[u8]) -> Wrap {
    let eph = StaticSecret::from(random::<32>());
    let shared = eph.diffie_hellman(&XPublic::from(to.dh_pk));
    let k = hkdf32(shared.as_bytes(), &[b"nv/wrap".as_slice(), ctx].concat());
    let nonce = [0u8; 12]; // key is single-use (fresh ephemeral), so a fixed nonce is safe
    let ct = ChaCha20Poly1305::new((&k).into())
        .encrypt(
            (&nonce).into(),
            Payload {
                msg: secret,
                aad: ctx,
            },
        )
        .expect("encrypt");
    Wrap {
        to: to.sign_pk,
        eph: XPublic::from(&eph).to_bytes(),
        ct,
    }
}

pub fn unwrap(w: &Wrap, my_dh_sk: &[u8; 32], ctx: &[u8]) -> Option<[u8; 32]> {
    let shared = StaticSecret::from(*my_dh_sk).diffie_hellman(&XPublic::from(w.eph));
    let k = hkdf32(shared.as_bytes(), &[b"nv/wrap".as_slice(), ctx].concat());
    let pt = ChaCha20Poly1305::new((&k).into())
        .decrypt(
            (&[0u8; 12]).into(),
            Payload {
                msg: &w.ct,
                aad: ctx,
            },
        )
        .ok()?;
    pt.try_into().ok()
}

/// 6-digit short authentication string + seal bytes from a Noise handshake hash.
pub fn sas(handshake_hash: &[u8]) -> (String, [u8; 9]) {
    let h = hkdf32(handshake_hash, b"nv/sas");
    let n = u32::from_be_bytes([h[0], h[1], h[2], h[3]]) % 1_000_000;
    let mut seal = [0u8; 9];
    seal.copy_from_slice(&h[8..17]);
    (format!("{:03} {:03}", n / 1000, n % 1000), seal)
}

/// Two decoy codes that differ from the real one, for the "pick the code you hear" check.
pub fn sas_decoys(code: &str, seed: &[u8]) -> Vec<String> {
    let h = hkdf32(seed, b"nv/sas-decoy");
    let digits: Vec<u32> = code
        .chars()
        .filter(|c| c.is_ascii_digit())
        .map(|c| c.to_digit(10).unwrap())
        .collect();
    let mut out = Vec::new();
    let mut i = 0usize;
    while out.len() < 2 {
        let mut d = digits.clone();
        // change two positions so decoys look plausible but are clearly different
        let p1 = (h[i % 32] as usize) % 6;
        let p2 = (p1 + 1 + (h[(i + 1) % 32] as usize) % 5) % 6;
        d[p1] = (d[p1] + 1 + (h[(i + 2) % 32] as u32) % 9) % 10;
        d[p2] = (d[p2] + 1 + (h[(i + 3) % 32] as u32) % 9) % 10;
        let s: String = d
            .iter()
            .map(|x| char::from_digit(*x, 10).unwrap())
            .collect();
        let s = format!("{} {}", &s[..3], &s[3..]);
        if s != code && !out.contains(&s) {
            out.push(s);
        }
        i += 4;
    }
    out
}

/// Argon2id key from a passphrase. `strong` = backups (64 MiB, 3 passes); otherwise PIN (19 MiB, 2 passes).
pub fn passphrase_key(pass: &str, salt: &[u8], strong: bool) -> anyhow::Result<[u8; 32]> {
    use argon2::{Algorithm, Argon2, Params, Version};
    let params = if strong {
        Params::new(64 * 1024, 3, 1, Some(32))
    } else {
        Params::new(19 * 1024, 2, 1, Some(32))
    }
    .map_err(|e| anyhow!("{e}"))?;
    let mut out = [0u8; 32];
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(pass.as_bytes(), salt, &mut out)
        .map_err(|e| anyhow!("{e}"))?;
    Ok(out)
}

/// Wrap a 32-byte key under a PIN: salt(16) || nonce(24) || ciphertext.
pub fn pin_wrap(pin: &str, key: &[u8; 32]) -> anyhow::Result<Vec<u8>> {
    let salt: [u8; 16] = random();
    let mut k = passphrase_key(pin, &salt, false)?;
    let (nonce, ct) = seal(&k, b"nv/pin", key);
    k.zeroize();
    Ok([salt.as_slice(), &nonce, &ct].concat())
}

/// Inverse of `pin_wrap`. Error "wrong PIN" on a bad PIN.
pub fn pin_unwrap(pin: &str, blob: &[u8]) -> anyhow::Result<zeroize::Zeroizing<[u8; 32]>> {
    if blob.len() < 16 + 24 + 16 {
        anyhow::bail!("bad PIN blob");
    }
    let mut k = passphrase_key(pin, &blob[..16], false)?;
    let m =
        open(&k, &blob[16..40], b"nv/pin", &blob[40..]).map_err(|_| anyhow::anyhow!("wrong PIN"));
    k.zeroize();
    let mut m = m?;
    let out: [u8; 32] = m
        .as_slice()
        .try_into()
        .map_err(|_| anyhow::anyhow!("bad PIN blob"))?;
    m.zeroize();
    Ok(zeroize::Zeroizing::new(out))
}

/// Crockford base32 without I, L, O, U: easy to read aloud and to type.
const RECOVERY_ALPHABET: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// A 120-bit recovery code, e.g. `7KQ2-M9XD-…` (6 groups of 4).
pub fn recovery_code() -> String {
    let bytes = zeroize::Zeroizing::new(random::<15>());
    let mut bits: u128 = 0;
    for b in bytes.iter() {
        bits = (bits << 8) | u128::from(*b);
    }
    let mut out = String::with_capacity(29);
    for i in 0..24 {
        if i > 0 && i % 4 == 0 {
            out.push('-');
        }
        let v = ((bits >> (5 * (23 - i))) & 31) as usize;
        out.push(RECOVERY_ALPHABET[v] as char);
    }
    out
}

/// Canonical form of a typed recovery code: uppercase, no separators, look-alikes folded.
pub fn normalize_recovery(code: &str) -> String {
    code.chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .map(|c| match c.to_ascii_uppercase() {
            'O' => '0',
            'I' | 'L' => '1',
            c => c,
        })
        .collect()
}
