# v1.0.1 — Documentation update (binary unchanged)

## What changed in v1.0.1

**The binary is byte-identical to v1.0.0.** Only the bundled documentation changed.

| | v1.0.0 | v1.0.1 |
|---|---|---|
| `k100-miner` md5 | `7d2a12e5eba0d7fd81aa15403ee0dded` | **same** |
| `libpearl5.so` md5 | `e464446c956c627f07990e291dbc42dd` | **same** |
| Bundled README | outdated, no verification guidance | **current, with verification section** |
| Reproducible build script | — | **`make_release.sh`** |

> The bundled README deliberately does **not** contain the archive's own SHA256 —
> that would be self-referential. The authoritative value lives in the repository
> README and on this Release page.

## Download

**[➡️ k100-miner-v1.0.1-linux-x64.tar.gz](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.1/k100-miner-v1.0.1-linux-x64.tar.gz)** — see the asset below

The SHA256 for this release is published on this page and in the repository README.

```
k100-miner-v1.0.1-linux-x64/
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
tar xzf k100-miner-v1.0.1-linux-x64.tar.gz
cd k100-miner-v1.0.1-linux-x64
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
| ✅ Verified | Runs, parses args, prints dev-fee fingerprint, wallet not extractable via `strings` |
| ✅ Verified | dev fee ratio: 15/15 tests, 72h simulation → 1.991% |
| ✅ Verified | **Real mining on K100 hardware** — 2026-11-16, Kylin V10, 8× K100_AI, 577 TH/s, 19 accepted / 0 rejected |
| ✅ Verified | Dev-fee account switch: after ~45 s, 6 shares all `result=True` on the dev account |
| ✅ Verified | Power scaling 200/250/350/400 W, best efficiency 0.208 TH/W at 250 W |
| ❌ Not verified | Long-run stability beyond 12 h (the 12 h run used the private build, not this package) |

**⇒ This build was verified on real K100_AI hardware on 2026-11-16.**
**⇒ The only untested dimension is long-run stability of this exact package.**
