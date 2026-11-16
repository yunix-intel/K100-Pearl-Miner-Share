**English** | [简体中文](README.zh-CN.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

# K100 Pearl (PRL) Miner

A Pearl (PRL) mining application for Hygon K100_AI (gfx928) DCUs.
**Distributed as a binary only — no source code is included.**

> ## ⚠️ Developer Fee Disclosure — Please Read Before Use
>
> **This software dedicates 2.0% of mining time to the developer.**
>
> | | |
> |---|---|
> | **Rate** | **2.0%**, settled strictly by *time* (72-hour simulation: 1.991%) |
> | **Dev wallet** | **Encrypted inside the binary — never appears in plaintext anywhere** |
> | **Wallet fingerprint** | `sha256:6050486ad79f` (first 12 hex chars) |
> | **On startup** | prints `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)` |
> | **During mining** | prints the cumulative ratio at every account switch — you can verify it stays near 2.0% |
> | **Opt-out** | `DEV_FEE_PERMILLE=0` disables it (for self-testing; no fee is paid when disabled) |
>
> ### Honest statement about verifiability
>
> Because the wallet address is **not** published in plaintext, **you cannot independently
> verify which wallet receives this 2%.**
>
> What you *can* verify: **the rate really is 2.0%** (from the cumulative statistics in the log).
>
> **If you require a verifiable recipient address, do not use this software.**
>
> **If you do not accept this rate, or do not accept that the recipient is not disclosed,
> do not use this software.**

---

## Contents

- [What This Is](#what-this-is)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Checking Status](#checking-status)
- [Stopping](#stopping)
- [How the Developer Fee Works](#how-the-developer-fee-works)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Version & License](#version--license)

---

## What This Is

A complete Pearl mining solution for an 8-card Hygon K100_AI system.
Measured **620 TH/s** (8 cards, pool accounting metric).

| Item | Value |
|---|---|
| Per-card hashrate | 72 TH/s |
| 8-card total | 620 TH/s (pool-reported; climbs as the rolling window fills) |
| Per attempt | 15.38 ms |
| Power | 400 W/card (`power1_cap_max` — hardware ceiling) |
| Temperature | Tj 78–82 °C |

> **⚠️ The pool's displayed hashrate ≈ real value × (minutes running / 60).**
> Right after startup it shows about one third; it takes a full hour to become accurate.

### How it works (high level)

```
1. Parse the job from the pool (header + target) and derive the job key
2. Generate the A/B noise matrices on the GPU
3. Per attempt: prepare the A-side selection, then run the MMA kernel
4. On a hit: build the proof locally (reusing GPU-computed chunk CVs) and submit
5. Every ~43 s the pool issues a new job; the B-side is cached per job (reuse-B)
```

---

## Requirements

| Item | Requirement |
|---|---|
| **Hardware** | Hygon K100_AI (gfx928) DCU, 8 cards recommended |
| **Driver** | Hygon DTK **26.04** (`/opt/dtk/dtk-26.04`) |
| **OS** | Linux x86_64, glibc 2.28+ |
| **Memory** | ≥ 16 GB |
| **Disk** | ≥ 200 MB free |
| **Network** | Outbound TCP 8048 to the pool |
| **Permissions** | root (to install into `/opt/vllm-fork`) |

### Supported pool

```
prl-hk.kryptex.network:8048   (TLS, type:v2 / gzip proof)
```

> The pool endpoint is compiled in. Only the account (`--account WALLET/WORKER`)
> is supplied by you.

---

## Installation

### Step 1 — Verify your DTK installation

```bash
ls /opt/dtk/dtk-26.04/bin/hipcc    # must exist
/opt/dtk/dtk-26.04/bin/rocm-smi    # must list 8 K100_AI cards
```

If this fails, install Hygon DTK 26.04 first. **The miner will not start without it.**

### Step 2 — Extract the release

```bash
tar xzf k100-miner-v1.0.0-linux-x64.tar.gz
cd k100-miner-v1.0.0-linux-x64
```

Contents:

```
k100-miner        the miner (single executable)
libpearl5.so      GPU kernel library
install.sh        installer
README.md         this file
LICENSE           license terms
CHANGELOG.md      change log
```

### Step 3 — Install

```bash
sudo ./install.sh
```

The installer places:

```
/opt/vllm-fork/k100-miner          main executable
/opt/vllm-fork/libpearl5.so        GPU library
/opt/vllm-fork/start.sh            8-card launcher (with CPU pinning)
/opt/vllm-fork/stop.sh             stop all
/opt/vllm-fork/stat.sh             status report
/var/log/vllm-fork/                log directory
```

Verify the installation:

```bash
ls -l /opt/vllm-fork/
/opt/vllm-fork/k100-miner --help
```

---

## Usage

### Single-card smoke test (do this first)

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH

HIP_VISIBLE_DEVICES=0 /opt/vllm-fork/k100-miner \
    --account YOUR_WALLET/YOUR_WORKER \
    --m 8192 --n 65536 --k 2048
```

**Expected output within the first 10 seconds:**

```
[init] m=8192 n=65536 k=2048
[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)
[transport] TLS prl-hk.kryptex.network:8048 (TLSv1.3)
[transport] gzip proof negotiated (type:v2)
[transport] authorize id=3 result=True error=None
[job] {"header": "...", "height": "...", "job_id": "...", "target": "..."}
[init] nbits=0x... cert=3 sess_key=...
[session] backend ready ...
[mine] #10 hit=0 15.4ms MAC 71.8 TH/s
```

**✅ If you see `authorize ... result=True` and `[mine]` lines — it is working.**

**❌ If `target` is all zeros, or there are no `[mine]` lines — stop and read
[Troubleshooting](#troubleshooting).**

### 8-card production

```bash
# The launcher pins each card to 4 disjoint logical CPU cores
sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

Optional: override the power cap (default 400 W, which is the hardware maximum)

```bash
POWER_W=350 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `--account` | **required** | Your pool account, format `WALLET/WORKER` |
| `--m` | 8192 | A-matrix rows (multiple of 128) |
| `--n` | 65536 | B-matrix columns (multiple of 128) |
| `--k` | 2048 | Common dimension (multiple of 32; ≥ 16 × rank = 2048) |
| `--attempts` | 0 | Number of attempts then exit; 0 = unlimited |
| `--dry-run` | off | Do not actually submit; print only |
| `--test-job` | off | **Do not connect to the pool**; use a fake job with `target = 0` |

> **⚠️ Never use `--test-job` for real mining.** It mines a fake job (`target = 0`,
> probability of a hit = 0); the pool will show you as offline and you earn nothing.

### Environment variables

| Variable | Description |
|---|---|
| `HIP_VISIBLE_DEVICES` | Select cards, e.g. `0` or `0,1,2,3` |
| `DEV_FEE_PERMILLE` | Developer fee in per-mille (default `20` = 2.0%). `0` disables |
| `LD_LIBRARY_PATH` | Must include `/opt/dtk/dtk-26.04/lib64` |

### What good performance looks like

| Metric | Expected |
|---|---|
| Per attempt | 15.0 – 16.5 ms |
| Per card | 68 – 73 TH/s |
| 8 cards | 550 – 580 TH/s (local measurement) |
| Power | ~395 – 400 W/card at the 400 W cap |
| Tj | 78 – 82 °C |

---

## Checking Status

```bash
/opt/vllm-fork/stat.sh
```

Sample output:

```
=== Per-card hashrate ===
  gpu0   72.1 TH/s
  gpu1   71.8 TH/s
  ...
  ═══════════════
  Total 574 TH/s

=== Shares ===
  HIT=386   accepted=383   rejected=3

=== devfee status ===
  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 2 次
```

### Manual checks

```bash
# Is it really connected to the pool?
grep 'authorize id=3 result=True' /var/log/vllm-fork/gpu0.log | head -1

# Share accounting
grep -c '\[HIT\]'       /var/log/vllm-fork/gpu*.log
grep -c 'result=True'   /var/log/vllm-fork/gpu*.log
grep -c 'result=False'  /var/log/vllm-fork/gpu*.log

# Developer fee — verify it stays near 2.0%
grep 'devfee' /var/log/vllm-fork/gpu*.log | tail -5
```

> **Note on the pool's displayed hashrate:** it is a rolling average (~60 min window).
> Right after startup you will see only ~1/3 of the real value. **This is normal** —
> it does not mean shares are being lost.

---

## Stopping

```bash
sudo /opt/vllm-fork/stop.sh
```

Then verify:

```bash
ps -ef | grep -c '[k]100-miner'    # should be 0
```

---

## How the Developer Fee Works

**We do not hide this. Here is the complete mechanism.**

### 1. Time-based quota, not share-based

```
For every 49 seconds mined for you, 1 second is owed to the developer (2%)
The formula need = user_s × p/(1−p) keeps the long-run ratio unbiased
```

Naive approaches fail:
- "switch when owed > 0" overpays badly (one user job followed by one dev job ≈ 50%)
- "decrement by dev seconds" underpays (the dev segment itself should also accrue)

### 2. Switches only at job boundaries

```
The pool issues a new job every ~43 s. When switching to the dev account the
miner re-authorizes; you will see this in the log:

  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 1 次
```

### 3. Wallet is encrypted inside the binary

```
The developer wallet is NOT a plaintext constant. It is XOR-encrypted ciphertext
plus a SHA256 integrity check.

- No address fragment can be found with `strings` on the binary
- Modifying any ciphertext or checksum byte ⇒ exit code 3 at startup
```

### 4. What you can and cannot verify

| | |
|---|---|
| ✅ **Can verify** | The rate really is 2.0% (from the cumulative log statistics) |
| ❌ **Cannot verify** | Which wallet receives it (the address is not published) |

**⇒ If a verifiable payout destination is a requirement for you, do not use this software.**

---

## FAQ

### Q1. `libpearl5.so: cannot open shared object file`

The GPU library is not at `/opt/vllm-fork/libpearl5.so`.
Re-run `sudo ./install.sh`, or copy `libpearl5.so` there manually.

### Q2. `hipGetDeviceCount() = 0`

`LD_LIBRARY_PATH` is missing the `lib64` directory:

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH
```

### Q3. The pool shows me offline / hashrate is 0

1. Check that `authorize ... result=True` appears in the log
2. Check that `--account` is `WALLET/WORKER` (a slash between them)
3. **Make sure you did not pass `--test-job`** — it mines a fake job and the pool sees nothing

### Q4. `integrity check failed` and the program exits

The embedded developer wallet failed its SHA256 check — the binary has been modified.
Download it again from the official release.

### Q5. Power only reaches 280 W and hashrate is low

Use `start.sh` rather than launching manually — it pins each card to 4 disjoint
logical CPU cores so the GPU is not starved by CPU-side preparation work.
This alone accounts for roughly 280 W → 399 W per card.

### Q6. Can I change the developer fee rate?

`DEV_FEE_PERMILLE=0` disables it. Other values also work (`=10` is 1%).
**Changing the rate does not affect the wallet integrity check.**

### Q7. Can I run fewer than 8 cards?

Yes. `HIP_VISIBLE_DEVICES=0,1` runs 2 cards. Hashrate scales roughly linearly.

### Q8. Why is my pool hashrate lower than `stat.sh` reports?

The pool's number is a ~60-minute rolling average. Also note the pool accounts
1 hash = 1 MAC (M·N·K), while some other tools report 2·M·N·K (MADD) — a factor of 2.
This miner logs the MAC figure, which matches the pool.

---

## Troubleshooting

### Nothing at all is printed

```bash
/opt/vllm-fork/k100-miner --help     # does the binary run at all?
ldd /opt/vllm-fork/k100-miner        # are shared libraries resolved?
```

### `authorize ... result=False`

Your account string is wrong. It must be exactly `WALLET/WORKER`
(kryptex uses `wallet.worker` on the wire; the miner converts the slash).

### Accepted shares but `result=False` is high (> 6%)

Shares are going stale. The pool changes jobs every ~43 s; the miner polls for
new jobs every 50 attempts. A small rejection rate (< 6%) is normal.
If it is much higher, check your network latency to the pool.

### Temperature above 90 °C

Lower the power cap:

```bash
POWER_W=300 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

> `power1_cap_max` is 400 W on this card. Values above 400 W are rejected by the driver.

### Where are the logs?

```
/var/log/vllm-fork/gpu0.log … gpu7.log
```

---

## Version & License

See [CHANGELOG.md](CHANGELOG.md) and [LICENSE](LICENSE).

**Binary distribution only — no source code is provided.**

Reverse engineering, modifying the integrity checks, or removing the developer
fee mechanism is prohibited by the license.

| Version | Date | Notes |
|---|---|---|
| 1.0.0 | 2026-11-10 | First binary release. 72 TH/s per card, 620 TH/s on 8 cards. 2.0% dev fee. |
