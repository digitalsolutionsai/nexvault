//! The session listener is bound to specific addresses, not the wildcard.

use std::net::{SocketAddr, TcpStream};
use std::time::Duration;

use nexvault_core::net;

#[test]
fn listener_is_not_on_every_address() {
    let (_l, port, addrs) = net::listen().unwrap();
    let ok = |ip: &str| {
        TcpStream::connect_timeout(
            &SocketAddr::new(ip.parse().unwrap(), port),
            Duration::from_secs(2),
        )
        .is_ok()
    };
    // advertised addresses and loopback answer
    assert!(ok("127.0.0.1"));
    for a in &addrs {
        assert!(ok(a), "{a}");
    }
    // 127.0.0.2 is a local address too, but not one we bound: a wildcard socket would accept it
    assert!(!ok("127.0.0.2"));
}

#[test]
fn sync_path_kind() {
    let k = |l: &str, p: &str| net::path_kind(l.parse().unwrap(), p.parse().unwrap());
    // same Wi-Fi
    assert_eq!(k("192.168.1.20", "192.168.1.31"), "nearby");
    assert_eq!(k("10.0.0.5", "10.0.0.9"), "nearby");
    assert_eq!(k("fe80::1", "fe80::2"), "nearby");
    assert_eq!(k("fd12::1", "fd12::2"), "nearby");
    // global IPv6 on the same /64 (same router) is still nearby
    assert_eq!(k("2001:db8:1:2::10", "2001:db8:1:2::20"), "nearby");
    // a phone on 4G/5G reached over IPv6
    assert_eq!(k("2001:db8:1:2::10", "2402:800:abcd:1::5"), "internet");
}
