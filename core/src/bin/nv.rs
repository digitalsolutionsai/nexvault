//! `nv` — command-line peer for testing NexVault against phones on the same network.
//!
//!   NV_KEY=HEX nv --dir D init NAME
//!   NV_KEY=HEX nv --dir D create WS_NAME          # prints invite, waits for joiners, finishes
//!   NV_KEY=HEX nv --dir D join-invite CODE        # prints choices, read the code from stdin
//!   NV_KEY=HEX nv --dir D ls
//!   NV_KEY=HEX nv --dir D add WS_ID NAME TEXT
//!   NV_KEY=HEX nv --dir D show WS_ID SECRET_ID
//!   NV_KEY=HEX nv --dir D host WS_ID [MINUTES]    # group sync host; prints ticket
//!   NV_KEY=HEX nv --dir D join TICKET
//!   NV_KEY=HEX nv --dir D call JSON               # raw API call

use std::io::{BufRead, Write};
use std::time::Duration;

use nexvault_core::api::Api;
use serde_json::{json, Value};

fn call(api: &mut Api, v: Value) -> Value {
    let out: Value = serde_json::from_str(&api.call(&v.to_string())).unwrap();
    if out["ok"] != true {
        eprintln!("error: {}", out["error"]);
        std::process::exit(1);
    }
    out["data"].clone()
}

fn line() -> String {
    let mut s = String::new();
    std::io::stdin().lock().read_line(&mut s).unwrap();
    s.trim().to_string()
}

fn main() {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let mut dir = "./nv-data".to_string();
    // Vault key: NV_KEY in the environment. `--key` still works for old scripts, but argv
    // is visible to every process on the machine (ps, /proc), so it prints a warning.
    // There is no default key: a forgotten key must not silently mean "all zeros".
    let mut key = std::env::var("NV_KEY").unwrap_or_default();
    while args.len() >= 2 && args[0].starts_with("--") {
        match args[0].as_str() {
            "--dir" => dir = args[1].clone(),
            "--key" => {
                eprintln!("nv: --key exposes the key to other processes; use NV_KEY=... instead");
                key = args[1].clone();
            }
            _ => {}
        }
        args.drain(..2);
    }
    if key.len() != 64 {
        eprintln!("nv: set NV_KEY to the vault key (64 hex characters)");
        std::process::exit(2);
    }
    let mut api = Api::default();
    call(&mut api, json!({"cmd": "open", "dir": dir, "key": key}));
    let a = |i: usize| args.get(i).cloned().unwrap_or_default();
    match a(0).as_str() {
        "init" => println!(
            "{}",
            call(&mut api, json!({"cmd": "create_identity", "name": a(1)}))
        ),
        "ls" => println!(
            "{}",
            serde_json::to_string_pretty(&call(&mut api, json!({"cmd": "workspaces"}))).unwrap()
        ),
        "ws" => println!(
            "{}",
            serde_json::to_string_pretty(&call(&mut api, json!({"cmd": "workspace", "ws": a(1)})))
                .unwrap()
        ),
        "add" => println!(
            "{}",
            call(
                &mut api,
                json!({"cmd": "put_secret", "ws": a(1), "name": a(2), "kind": "text", "text": a(3)})
            )
        ),
        "show" => println!(
            "{}",
            call(&mut api, json!({"cmd": "reveal", "ws": a(1), "id": a(2)}))
        ),
        "call" => println!("{}", api.call(&a(1))),
        "create" => {
            let inv = call(&mut api, json!({"cmd": "ceremony_create", "name": a(1)}));
            println!("INVITE {}", inv["invite"].as_str().unwrap());
            println!("Waiting for members. Each one is accepted once they pick the right code. Press Enter to finish.");
            let (tx, rx) = std::sync::mpsc::channel();
            std::thread::spawn(move || {
                let _ = line();
                let _ = tx.send(());
            });
            let mut shown = std::collections::HashSet::new();
            loop {
                let st = call(&mut api, json!({"cmd": "ceremony_status"}));
                for j in st["joiners"].as_array().unwrap() {
                    let pk = j["pk"].as_str().unwrap().to_string();
                    if shown.insert(format!("{pk}-seen")) {
                        println!("JOINER {} code={} seal={}", j["name"], j["code"], j["seal"]);
                    }
                    if j["verified"] == true && shown.insert(format!("{pk}-ok")) {
                        call(&mut api, json!({"cmd": "ceremony_accept", "pk": pk}));
                        println!("ACCEPTED {}", j["name"]);
                    }
                    if j["failed"] == true && shown.insert(format!("{pk}-bad")) {
                        println!("FAILED {} picked a wrong code", j["name"]);
                    }
                }
                if rx.recv_timeout(Duration::from_millis(300)).is_ok() {
                    break;
                }
            }
            println!(
                "WS {}",
                call(&mut api, json!({"cmd": "ceremony_finish"}))["ws"]
                    .as_str()
                    .unwrap()
            );
        }
        "join-invite" => {
            call(&mut api, json!({"cmd": "ceremony_join", "invite": a(1)}));
            let mut asked = false;
            loop {
                let st = call(&mut api, json!({"cmd": "ceremony_join_status"}));
                match st["state"].as_str().unwrap() {
                    "verify" if !asked => {
                        asked = true;
                        println!("SEAL {} CHOICES {}", st["seal"], st["choices"]);
                        print!("code> ");
                        std::io::stdout().flush().unwrap();
                        let c = line();
                        println!(
                            "{}",
                            call(&mut api, json!({"cmd": "ceremony_pick", "code": c}))
                        );
                    }
                    "done" => {
                        println!("WS {}", st["ws"].as_str().unwrap());
                        break;
                    }
                    "aborted" | "error" => {
                        println!("{st}");
                        std::process::exit(2);
                    }
                    _ => {}
                }
                std::thread::sleep(Duration::from_millis(200));
            }
        }
        "host" => {
            let mins: u64 = a(2).parse().unwrap_or(5);
            let h = call(
                &mut api,
                json!({"cmd": "sync_host", "ws": a(1), "minutes": mins}),
            );
            println!("TICKET {}", h["ticket"].as_str().unwrap());
            let mut last = String::new();
            loop {
                let st = call(&mut api, json!({"cmd": "sync_host_status"}));
                let p = st["peers"].to_string();
                if p != last {
                    println!("PEERS {p}");
                    last = p;
                }
                if st["accepting"] == false {
                    println!("EXPIRED");
                    break;
                }
                std::thread::sleep(Duration::from_millis(300));
            }
        }
        "join" => {
            call(&mut api, json!({"cmd": "sync_join", "ticket": a(1)}));
            let mut last = String::new();
            for _ in 0..200 {
                let st = call(&mut api, json!({"cmd": "sync_join_status"}));
                let s = st.to_string();
                if s != last {
                    println!("STATUS {s}");
                    last = s;
                }
                if matches!(st["state"].as_str(), Some("done" | "error" | "closed")) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(150));
            }
        }
        _ => eprintln!("see src/bin/nv.rs for usage"),
    }
}
