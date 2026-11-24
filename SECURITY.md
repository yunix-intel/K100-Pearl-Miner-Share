# Security

## Official distribution — one channel only

There is exactly **one** official distribution channel:

```
https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases
```

We do not publish mirrors, torrents, or third-party hosting. If you obtained
`k100-miner-v1.0.0-linux-x64.tar.gz` from anywhere else, **its content is not
ours, and we cannot vouch for it.**

## Verify your download before running it

Every release lists its checksum. Always compare before executing:

```bash
sha256sum k100-miner-v1.0.3-linux-x64.tar.gz
```

Expected for **v1.0.3** (current):

```
217cbab42e38311b0b23e7fcab938f7e150b20c968be34d240189c16cb9a8665
```

MD5 (for convenience only — SHA256 is authoritative):
```
cd49f47254bb881f9eefbbf8409acd1d
```

Earlier releases — still downloadable, and **v1.0.0–v1.0.2 do not verify the pool's
TLS certificate** (see *Supported versions* below):

| Version | SHA256 | MD5 |
|---|---|---|
| v1.0.2 | `ee009d3b4c53f8f4b6061044338af548825a246d331f2024a421d5211c5ae81f` | `e75010575d14c2a40a0c4f5e47e9731c` |
| v1.0.1 | `d8ed939d9ebc0cbe974dbb34af1cadf91df0863d78af3fc71eb83fbeb13a7f5a` | `b43f899d7463f071b54af7798a40310c` |
| v1.0.0 | `715fd8679df8fd22d7e592c8b135fc5d04968cc40ad89d6062374d31be07d803` | `a6cbd72188ad077dfe8b58fc1cc36019` |

**If the checksum does not match: do not run the binary.** Delete the archive
and download it again from the Release page above.

## Fake and "cracked" builds

**Do not run any build described as "no-fee", "cracked", "unlocked", or
"dev-fee removed".**

Why this matters:

- The developer wallet is XOR-obfuscated with a SHA256 integrity check (obfuscation, not real encryption — see below). If you
  modify the ciphertext or the checksum inside **our** binary, it refuses to
  start (`exit code 3`).
- But a third party who rebuilds from decompiled code will not trip that check.
  Such a rebuild can do **anything** — redirect your mining rewards, install a
  backdoor, or exfiltrate your pool credentials.
- We cannot audit or vouch for any binary we did not build.

If someone offers you a modified version, treat it as malware until proven
otherwise.

## Reporting a security issue

This is a closed-source binary, so the classic "read the code and send a patch"
workflow does not apply. Still, two categories of reports are genuinely useful:

**1. Integrity / settlement issues** — e.g. the dev fee never settles, the
binary starts despite a corrupted checksum, or the log reports a fee ratio far
from the configured value.

**2. Supply-chain issues** — e.g. you found a copy of the release on a
third-party site, or the Release asset differs from the checksum above.

Please report these through a **private security advisory**, not a public issue:

```
https://github.com/yunix-intel/K100-Pearl-Miner-Share/security/advisories/new
```

Include: the release tag, the output of `sha256sum` on your archive, your OS
and glibc version (`ldd --version`), and the relevant log lines.

## What this software does and does not do

For transparency, since you cannot inspect the source:

| | |
|---|---|
| Reads pool data | job header, target, job_id from the configured pool endpoint |
| Writes to disk | `/opt/vllm-fork/` (install), `/var/log/vllm-fork/` (logs), `/tmp/last_proof_*` (last submitted proof, for debugging) |
| **Unpacks to `/tmp`** | This is a Nuitka `--onefile` binary: each process unpack~123 MB into `/tmp/onefile_<pid>_×××/` at startup and removes it on clean exit. **8 cards ≈ 1 GB of `/tmp`.** A `SIGKILL` or power loss can leave `onefile_*` directories behind — safe to delete when no miner is running. |
| **Runs `sh -c "ps aux"`** | Once at startup, to count processes. Read-only; nothing from it is transmitted. |
| Network | outbound TLS to the pool endpoint only. **Certificate verification is strict (v1.0.3+).** v1.0.0–v1.0.2 accepted any certificate (`CERT_NONE`), which allowed a man-in-the-middle to impersonate the pool — do not use those versions on an untrusted network. |
| Does **not** | phone home, collect telemetry, run a remote shell, modify system files outside the paths above |
| Dev fee | 2.0% of mining time, settled by time quota, paid to a wallet embedded in the binary. **At 2% the first account switch takes ≈2205 s (≈37 min) of user time** — `job_est/(p/(1−p))` with `job_est≈45 s`. |

The dev-fee recipient wallet is stored **XOR-obfuscated with a checksum — not
cryptographically encrypted.** `strings` will not find it, but anyone who unpacks
the binary's payload can recover the address in minutes. We do not claim otherwise.
What *is* enforced is integrity: modifying the wallet ciphertext, the key, or the
checksum makes the miner refuse to start (`exit code 3`), so the fee can neither be
redirected nor disabled by patching. The SHA256 fingerprint is `6050486ad79f`.

## Supported versions

Only the latest release receives fixes. Older binaries are unsupported the
moment a new release is published.

| Version | Status | Notes |
|---|---|---|
| **v1.0.3** | **current** | strict TLS verification |
| v1.0.2 and earlier | **unsupported — upgrade** | `verify_mode = CERT_NONE`: any certificate is accepted, so a network attacker can impersonate the pool, read your wallet, front-run valid proofs and feed fake jobs. Do not run these on an untrusted network. |
