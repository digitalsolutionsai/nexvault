# NexVault

Share secrets (logins, API keys, Wi-Fi passwords, secure notes, and files such as .env, SSH keys, .p12 certificates, keystores and Apple .p8 keys)
inside a small group — founders, a DevOps team, a family — **without any server**.

Each workspace is a group of equal peers. Data lives only on the members' devices and syncs
when they are close by (same Wi‑Fi or hotspot), or over IPv6 with a QR code that expires after
5 minutes. Workspaces are created in person: members read a short code aloud to each other, so
there is no account, no invite link to intercept and no company in the middle.

- Architecture: [docs/architecture.md](docs/architecture.md)
- Threat model: [docs/threat-model.md](docs/threat-model.md)
- UI notes: [docs/ui.md](docs/ui.md), mockups in `design/`

The design docs are written in Vietnamese; the app speaks English and Vietnamese.

## Layout

| Path | What |
|---|---|
| `core/` | Rust: signed log, workspace keys, Noise sync, in-person ceremony, encrypted vault, JSON API (`nv_call` over FFI) and the `nv` CLI |
| `app/` | Flutter (Android, iOS) calling the core through `dart:ffi`; Kotlin / Swift for Keystore / Keychain, biometric and screen-lock prompts, screenshot blocking, sensitive clipboard |
| `design/` | Workspace seal (`seal.js`), icon, mockups |
| `scripts/` | Android / iOS builds |

## Build

Needs Rust stable, `cargo-ndk`, Android NDK 28, Flutter 3.x, JDK 17; Xcode for iOS.

```sh
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install cargo-ndk
scripts/build-android.sh            # release APKs per ABI
scripts/build-android.sh debug      # debug APK
scripts/build-android.sh appbundle  # AAB for Google Play

rustup target add aarch64-apple-ios aarch64-apple-ios-sim
scripts/build-ios.sh                # device build (needs a signing team)
scripts/build-ios.sh sim            # simulator build
```

**Android release signing**: create `app/android/key.properties` (gitignored):

```properties
storeFile=/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Without it the release build is signed with the debug key (fine for testing, refused by Play).
For iOS, set your own `DEVELOPMENT_TEAM` in Xcode.

## Test

```sh
cd core && cargo test --release     # real TCP sync, ceremony, add/remove members, conflicts, backups, forged logs
cd app && flutter analyze && flutter test
cd app && flutter test integration_test/smoke_test.dart -d <device>   # on an emulator / simulator
```

CI: `.github/workflows/ci.yml` (fmt, clippy `-D warnings`, tests, analyze, APK build).

### Trying it against a phone with the CLI

```sh
cd core && cargo build --release --bin nv
export NV_KEY=$(openssl rand -hex 32)   # vault key; not passed on argv, where other processes can read it
./target/release/nv --dir /tmp/minh init Minh
./target/release/nv --dir /tmp/minh join-invite 'nexvault://i/...'   # then type the code the creator reads out
./target/release/nv --dir /tmp/minh join 'nexvault://t/...'
```

With an emulator (NAT), forward the app's port and set `NV_CONNECT_EXTRA=127.0.0.1` so the CLI
also tries that address.

Debug builds allow screenshots when a marker file exists:
`adb shell run-as vn.dsai.nexvault touch files/allow_screenshots`. Release builds always block them.

## Security

Please report vulnerabilities privately, see [SECURITY.md](SECURITY.md).

## License

Copyright © 2026 Digital Solutions AI Company Limited.

NexVault is free software under the [GNU Affero General Public License v3.0](LICENSE). If you
distribute a modified version, you must publish its source under the same license.
