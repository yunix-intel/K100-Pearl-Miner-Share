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
sha256sum k100-miner-v1.0.0-linux-x64.tar.gz
```

Expected for **v1.0.0**:

```
715fd8679df8fd22d7e592c8b135fc5d04968cc40ad89d6062374d31be07d803
```

MD5 (for convenience only — SHA256 is authoritative):
```
a6cbd72188ad077dfe8b58fc1cc36019
```

**If the checksum does not match: do not run the binary.** Delete the archive
and download it again from the Release page above.

## Fake and "cracked" builds

**Do not run any build described as "no-fee", "cracked", "unlocked", or
"dev-fee removed".**

Why this matters:

- The developer wallet is XOR-encrypted with a SHA256 integrity check. If you
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
| Network | outbound TLS to the pool endpoint only |
| Does **not** | phone home, collect telemetry, run a remote shell, modify system files outside the paths above |
| Dev fee | 2.0% of mining time, settled by time quota, paid to a wallet embedded in the binary |

The dev-fee recipient wallet is **not** published (only its SHA256 fingerprint,
`6050486ad79f`). You can verify the **rate** from the cumulative statistics the
miner prints at each account switch, but you cannot verify the recipient. If a
verifiable payout destination is a requirement for you, do not use this
software.

## Supported versions

Only the latest release receives fixes. Older binaries are unsupported the
moment a new release is published.
