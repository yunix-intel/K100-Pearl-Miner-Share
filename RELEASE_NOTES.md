# v1.0.2 — Rebuilt binary + install/stop fixes

## What changed in v1.0.2

**The binary was rebuilt for this release** (first rebuild since v1.0.0).
Reason: v1.0.0/v1.0.1's `--help` exposed 8 leftover vLLM-style options that the
code never referenced. Removing them requires a recompile.

`libpearl5.so` is unchanged. Mining behaviour, hashrate and the dev-fee
mechanism are unchanged — verified on real hardware (see below).

| | v1.0.1 | v1.0.2 |
|---|---|---|
| `k100-miner` md5 | `7d2a12e5` | **`ea683cbf`** (rebuilt) |
| `libpearl5.so` md5 | `e464446c` | `e464446c` (unchanged) |
| `--help` | shows 8 unused vLLM-style args | **only the 7 real args** |
| `stop.sh` | kills any process whose argv contains `k100-miner` | **matches `/proc/<pid>/exe` exactly** |
| Log dir / files | 755 / 644 (world-readable) | **700 / 600** |
| Pre-install checks | none | **7-item dependency check, aborts before installing** |
| `start.sh` path | hardcoded `/opt/vllm-fork` | **follows `$DST`** |

> The bundled README deliberately does **not** contain the archive's own SHA256 —
> that would be self-referential. The authoritative value lives in the repository
> README and on this Release page.

## Download

**[➡️ k100-miner-v1.0.2-linux-x64.tar.gz](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.2/k100-miner-v1.0.2-linux-x64.tar.gz)** — see the asset below

The SHA256 for this release is published on this page and in the repository README.

```
k100-miner-v1.0.2-linux-x64/
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
- Dev wallet: **encrypted inside the binary** — never appears in plaintext
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
tar xzf k100-miner-v1.0.2-linux-x64.tar.gz
cd k100-miner-v1.0.2-linux-x64
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
| ✅ Verified on **this build** (2026-11-24) | Runs on K100_AI; `--help` shows only the 7 real args; single-card 71.0–71.6 TH/s at 15.3–15.6 ms/attempt; `authorize result=True`; 0 Traceback |
| ✅ Verified on **this build** | Dev-fee line prints `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)`; embedded wallet decrypts and its `sha256[:16]` matches the built-in checksum |
| ✅ Verified on v1.0.0 (2026-11-16) | Full 8-card run: 577 TH/s at 400 W, 73.9 TH/s single card, 19 accepted / 0 rejected |
| ✅ Verified on v1.0.0 | Dev-fee account switch after ~45 s: 6 shares all `result=True` on the dev account |
| ✅ Verified on v1.0.0 | Power scaling 200/250/350/400 W; best efficiency 0.208 TH/W at 250 W |
| ✅ Verified (all versions) | Dev-fee ratio: 15/15 unit tests, 72-hour simulation → 1.991% |
| ❌ Not verified | Long-run stability (> 12 h) of **this exact binary**. The 12 h run used the private (0 % fee) build. |

**⇒ The v1.0.2 binary was rebuilt and re-verified on real K100_AI hardware on 2026-11-24 (single card).**
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

