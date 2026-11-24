# v1.0.3 — Security fix (TLS verification) + doc corrections

## What changed in v1.0.3

**Security release — upgrade if you run v1.0.0–v1.0.2.**

### 🔴 v1.0.0–v1.0.2 did not verify the pool's TLS certificate

Those versions called `ssl.create_default_context()` and then set
`check_hostname = False` / `verify_mode = CERT_NONE`, i.e. **any** certificate was
accepted. Anyone able to hijack DNS, routing or ARP could impersonate the pool and
read your wallet/worker, intercept and front-run valid proofs, feed fake jobs, or
drop your shares.

The pool's real certificate is valid (Sectigo, SAN covers `*.kryptex.network`,
valid until 2027-04), so strict verification costs nothing. It is now the default.

### Other fixes

| | v1.0.2 | v1.0.3 |
|---|---|---|
| TLS to pool | `CERT_NONE` (accepts anything) | **`CERT_REQUIRED` + hostname check** |
| `libpearl5.so` location | hardcoded `/opt/vllm-fork/…` — `DST=` installs could not run | `K100_LIB` → beside the binary → old default |
| `stat.sh` hits | `grep '[HIT]'` — binary never prints it, always 0 | `[MATCH] ★★★` |
| `stat.sh` accepted | counted the `authorize` reply too (showed `accepted=8` with 0 shares) | only `◀ id=` replies |
| CPU pin table | hardcoded cores 32–115 — `taskset` fails on machines with < 116 cores | auto-detect, even split if fewer |
| Install over existing files | silent overwrite | backs up to `<DST>.bak.<timestamp>` first |
| `--account` without `/` | Traceback + exit 1 | readable error before connecting |

### Documentation corrected against the actual binary

- Users were told to look for `[mine]` lines — the binary prints `[compute]`, never `[mine]`.
- Sample log line showed `[job] {...}` — the binary prints `[session] {...}`.
- "`authorize result=True` means it's working" — the pool accepts **any** string;
  `TEST/TESTW` also gets `True` and even gets shares accepted. The only authoritative
  check is your balance on the pool dashboard.
- "Account switches to the dev wallet after ~45 s" — at 2 % the **first** switch needs
  ≈2205 s (**≈37 min**) of user time: `job_est/(p/(1−p))` with `job_est ≈ 45 s`.
  The 45 s figure corresponds to a 50 % rate.
- Disk requirement: each process also unpacks ≈123 MB into `/tmp`; 8 cards ≈ 1 GB.
- `glibc 2.28+` → the binary actually needs only `GLIBC_2.14`.
- The dev-fee wallet is XOR-obfuscated, **not** cryptographically hidden, and can be
  recovered from the payload in minutes. SECURITY.md now says so, and states what
  *is* enforced (integrity — any tampering gives `exit 3`).
- SECURITY.md now discloses the startup `sh -c "ps aux"` and the `/tmp/onefile_*`
  extraction.

`libpearl5.so` is unchanged (`e464446c`). Hashrate and the dev-fee mechanism are
unchanged; verified on real hardware (below).

> The bundled README deliberately does **not** contain the archive's own SHA256 —
> that would be self-referential. The authoritative value lives in the repository
> README and on this Release page.

## Download

**[➡️ k100-miner-v1.0.3-linux-x64.tar.gz](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.3/k100-miner-v1.0.3-linux-x64.tar.gz)** — see the asset below

The SHA256 for this release is published on this page and in the repository README.

```
k100-miner-v1.0.3-linux-x64/
├── k100-miner        29 MB   the miner (single executable, compiled from C)
├── libpearl5.so      121 KB  GPU kernel library
├── install.sh        3.4 KB  installer
├── README.md                  English
├── README.zh-CN.md            简体中文
├── README.ko.md               한국어
├── README.ja.md               日本語
├── LICENSE
└── CHANGELOG.md
```

## ⚠️ Developer fee: 2.0%

This software dedicates **2.0% of mining time** to the developer.

- Rate: **2.0%**, settled strictly by time (72-hour simulation: 1.991%)
- Dev wallet: **XOR-obfuscated inside the binary** with a checksum — no plaintext copy (`strings` finds nothing; the payload can be unpacked — see below)
- Wallet fingerprint: `sha256:6050486ad79f`
- Startup line: `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)`
- Disable: `DEV_FEE_PERMILLE=0`

**Verifiability:** you can verify the *rate* (from log statistics), but **not the
recipient wallet** (the address is not published). If you require a verifiable
recipient, do not use this software.

## Requirements

| | |
|---|---|
| Hardware | Hygon K100_AI (gfx928) DCU, 8 cards recommended |
| Driver | Hygon DTK 26.04 |
| OS | Linux x86_64, glibc 2.28+ |

## Quick start

```bash
tar xzf k100-miner-v1.0.3-linux-x64.tar.gz
cd k100-miner-v1.0.3-linux-x64
sudo ./install.sh

export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:$LD_LIBRARY_PATH
HIP_VISIBLE_DEVICES=0 /opt/vllm-fork/k100-miner --account WALLET/WORKER --m 8192 --n 65536 --k 2048
```

Expect `authorize ... result=True` and `[mine]` lines within 10 seconds.

## Performance

| | |
|---|---|
| Per card | 72 TH/s |
| 8 cards | 620 TH/s (pool accounting) |
| Per attempt | 15.38 ms |
| Power | 400 W/card (`power1_cap_max`) |

## What's in this build

- **Nuitka-compiled** (C binary, not a packed .pyc — reverse engineering is much harder)
- Wallet ciphertext, XOR key, checksum and address are **not present as contiguous bytes** in the binary
- CPU pinning in the launcher (each card gets 4 disjoint logical cores) — this alone is 280 W → 399 W per card
- 2.0% dev fee with time-based quota (`need = user_s × p/(1−p)`, unbiased in the long run)

## Verified / Not verified

| | |
|---|---|
| ✅ Verified on **this build** (2026-11-24) | Runs on K100_AI; `--help` shows only the 7 real args; single-card **71.6–72.3 TH/s** at 15.3–15.6 ms/attempt; `authorize result=True`; 0 Traceback |
| ✅ Verified on **this build** | **Strict TLS**: connects to the pool with `CERT_REQUIRED` + hostname check and no certificate error (pool cert is Sectigo, SAN `*.kryptex.network`, valid to 2027-04) |
| ✅ Verified on **this build** | Library path: falls back to `/opt/vllm-fork` when absent, honours `K100_LIB`, and fails with a clear `OSError` on a bogus path |
| ✅ Verified on **this build** | `--account TESTONLY` (no slash) → readable argparse error instead of a Traceback |
| ✅ Verified on **this build** | Dev-fee line prints `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)`; embedded wallet decrypts and its `sha256[:16]` matches the built-in checksum |
| ✅ Verified on v1.0.0 (2026-11-16) | Full 8-card run: 577 TH/s at 400 W, 73.9 TH/s single card, 19 accepted / 0 rejected |
| ✅ Verified on v1.0.0 | Dev-fee account switch does happen and shares are accepted on the dev account. **Timing corrected in v1.0.3**: at 2 % the *first* switch needs ≈2205 s (≈37 min) of user time (`job_est/(p/(1−p))`, `job_est≈45 s`). The earlier “≈45 s” figure was wrong — that corresponds to a 50 % rate. |
| ✅ Verified on v1.0.0 | Power scaling 200/250/350/400 W; best efficiency 0.208 TH/W at 250 W |
| ✅ Verified (all versions) | Dev-fee ratio: 15/15 unit tests, 72-hour simulation → 1.991% |
| ❌ Not verified | Long-run stability (> 12 h) of **this exact binary**. The 12 h run used the private (0 % fee) build. |

**⇒ The v1.0.3 binary was rebuilt and re-verified on real K100_AI hardware on 2026-11-24 (single card).**
**⇒ The 8-card / power-scaling figures were measured on v1.0.0, whose mining code is identical.**
**⇒ The only untested dimension is multi-hour stability of this exact binary.**

### About the dev-fee wallet

The wallet is stored XOR-obfuscated with a checksum, **not** encrypted in any
cryptographically meaningful sense. `strings` will not find it, but someone who
decompresses the binary's payload can recover the address in minutes. We do not
claim otherwise.

What *is* enforced is **integrity**: if the wallet ciphertext, the key, or the
checksum is modified in any way, the miner refuses to start (`exit code 3`).
So the fee cannot be redirected and cannot be disabled by patching these values.

