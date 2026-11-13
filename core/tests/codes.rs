//! Damaged, truncated or garbage codes must give a clear error, never panic.

use nexvault_core::ticket::*;

#[test]
fn damaged_codes_are_rejected_cleanly() {
    let key = [7u8; 32];
    let cases = [
        TICKET_PREFIX.to_string(),
        format!("{TICKET_PREFIX}AAAA"),
        format!("{TICKET_PREFIX}not*base64!"),
        format!("{TICKET_PREFIX}{}", "A".repeat(30)),
    ];
    for c in &cases {
        let e = decode_ticket(c, &key).unwrap_err().to_string();
        assert_eq!(e, "code is damaged or incomplete", "{c}");
        let e = ticket_ws(c).unwrap_err().to_string();
        assert_eq!(e, "code is damaged or incomplete", "{c}");
    }
    for c in [
        INVITE_PREFIX.to_string(),
        format!("{INVITE_PREFIX}qGF2AWd3c19uYW1lZkRld"),
        format!("{INVITE_PREFIX}%%%"),
    ] {
        let e = decode_invite(&c).unwrap_err().to_string();
        assert_eq!(e, "code is damaged or incomplete", "{c}");
    }
    assert_eq!(
        decode_invite("hello").unwrap_err().to_string(),
        "not an invite code"
    );
}
