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
