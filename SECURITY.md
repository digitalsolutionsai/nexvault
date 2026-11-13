# Security policy

NexVault holds other people's keys and passwords, so we treat security reports as the top
priority.

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on this repository. Include what you found, how to
reproduce it, and the version or commit.

We aim to acknowledge reports within 3 working days, and to agree on a fix and disclosure date
with you. We are happy to credit you in the release notes unless you prefer otherwise.

## Scope

In scope: the Rust core (`core/`), the apps (`app/`), the sync and ceremony protocols, the
on-device storage of keys and the release builds we publish.

Useful background: [docs/threat-model.md](docs/threat-model.md) lists what NexVault defends
against and what it deliberately does not (for example a fully compromised, rooted device).
