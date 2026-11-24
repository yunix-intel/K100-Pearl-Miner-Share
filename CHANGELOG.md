# 变更记录

## v1.0.4 (2026-11-24)

**安装脚本修复版。二进制与 v1.0.3 完全相同（md5 `c9a1a6a5`）。**

### 🔴 修复：首次安装打印「安装完成」却 exit 1

v1.0.3 的 `install.sh` 最后一行是：

```bash
[ -n "${BAK:-}" ] && echo "  还原: cp -p $BAK/* $DST/"
```

在 `set -euo pipefail` 下，全新安装时 `BAK` 未设置 ⇒ 这一行返回 1 ⇒ **脚本以 1 退出**。
前面已经打印「安装完成」，但 `sudo ./install.sh && ...` 或自动化部署会判定失败。
（二次安装有备份，`BAK` 非空，所以当时没暴露。）

改为 `if ... then ... fi`，实测首次/二次安装都 exit 0。

### 🟠 修复：`chmod 755 "$DST"` 会放宽既有目录权限

v1.0.3 无条件 `mkdir -p "$DST"; chmod 755 "$DST"`。若 `DST` 是别人设的 700 目录
（默认路径 `/opt/vllm-fork` 就是），安装会把权限放宽。
现改为：目录已存在则不动它的权限。

### 🟠 修复：绑核退化分支在 <32 核时重叠/越界

v1.0.3 声称「核数不足时均匀分配」，但 8 卡 × 4 核 = 32 核是硬下限。
8 核机器上 GPU5–7 的核号会越界，`taskset` 失败，脚本仍打印「已启动 8 个进程」。
现在：核数不足时**下调卡数**，并**检查每个进程启动后是否立刻退出**，
有失败则打印日志尾部并以 exit 1 结束。

### 🟡 `start.sh` 增加库存在性检查

若 `K100_LIB` 指错（或安装不完整），现在启动前就报「找不到 …」并退出，
而不是让二进制内部的 `ctypes.CDLL` 抛 Traceback。

### 🟡 文档：README 补「2% 首切 ≈37 分钟」

之前只在 `SECURITY.md` / `RELEASE_NOTES.md` 写了这个数字，README（用户最先看的）
没有，容易被「45 秒」的旧说法误导。四语 README 均已补上。

---

## v1.0.3 (2026-11-24)

**安全修复版。建议所有用户升级。**

- `k100-miner` 重新编译（md5 见 Release 页）
- `libpearl5.so` 未变（`e464446c`）

### 🔴 修复：TLS 证书校验被关闭（中间人可冒充矿池）

v1.0.0–v1.0.2 里 `Transport.connect()` 是：

```python
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode  = ssl.CERT_NONE      # ← 任何证书都接受
```

后果：能劫持 DNS/路由/ARP 的人可以冒充矿池 —— 读取你的钱包与 worker、
截获并抢提有效 proof、喂假 job、丢 share。

矿池证书实测是**有效**的（Sectigo 签发，SAN 覆盖 `*.kryptex.network`、
有效期至 2027-04），因此打开校验没有任何兼容性代价。现在改为默认的严格校验。

### 🔴 修复：库路径写死 `/opt/vllm-fork/libpearl5.so`

旧版 `LIB = '/opt/vllm-fork/libpearl5.so'`，导致 `DST=/other/path` 安装后
二进制仍去旧路径找库，实际跑不起来（v1.0.2 只修了 `start.sh`，没修二进制）。
现在顺序为：`K100_LIB` 环境变量 → 与可执行文件同目录 → 旧默认路径。

### 🔴 修复：`stat.sh` 的命中统计永远为 0

旧版 `grep '[HIT]'`，但二进制**从不打印 `[HIT]`**（打印的是 `[MATCH]`）。
且「接受」把 `authorize` 应答也算成了 share —— 8 卡 0 share 时会显示「接受=8」。

现在按真实标签统计：

```
命中(本地 MATCH) = grep -c '[MATCH] ★★★'
已提交(publish)  = grep -c '[publish] job='
接受             = grep '◀ id=' | grep -c 'result=True'
拒绝             = grep '◀ id=' | grep -c 'result=False'
```

### 🟠 修复：`start.sh` 绑核表硬编码，少于 116 核的机器直接失败

旧版绑核表写死 32–115 号核（192 核 K100 的调优值）。少于 116 核的机器
`taskset` 会报「无效的参数」，矿工起不来。现在按 `nproc` 自适应：
≥116 核用调优表，否则按卡数均匀分配。

### 🟠 修复：`install.sh` 静默覆盖已有文件

旧版直接 `install -m755` 覆盖 `$DST` 下同名文件。若该目录被别的程序
（例如真的 vLLM fork）占用，会被无提示破坏。
现在覆盖前先备份到 `<DST>.bak.<时间戳>` 并打印还原命令。

### 🟠 修复：`--account` 格式错误直接抛 Traceback

旧版传 `--account TESTONLY`（无斜杠）会崩出 Traceback + exit 1。
现在提前校验并给出可读报错。

### 🟡 文档修正（多处与实现不符）

| 原文档 | 实际 | 已改为 |
|---|---|---|
| 让用户找 `[mine]` 行判断正常 | 二进制打印 `[compute]`，从不打印 `[mine]` | `[compute]` |
| 示例日志行 `[job] {...}` | 二进制打印 `[session] {...}` | `[session]` |
| 「`authorize result=True` 表示正常」 | 矿池接受任意字符串；`TEST/TESTW` 也是 `True`，share 也被接受 | 明确说明这不是钱包校验；要看矿池后台余额 |
| 「45 秒后切到开发者账户」 | 2% 下首切 = `job_est/(p/(1−p))` ≈ **2205 秒（37 分钟）**；45 秒对应的是 50% 费率 | 已如实写明 |
| 磁盘要求 ≥200 MB | 每进程还要解压约 123 MB 到 `/tmp`，8 卡约 1 GB | 补 `/tmp` 与 CPU 核数要求 |
| `glibc 2.28+` | 二进制实际只需 `GLIBC_2.14` | 改为 ≥2.14（注明实测环境 2.28） |
| 「钱包加密内嵌、永不明文、无法验证收款方」 | XOR 混淆，可还原（已实测） | SECURITY.md 已如实说明：混淆≠加密、可还原；但改任一常量 → exit 3 |
| 未披露 `sh -c "ps aux"` 与 `/tmp/onefile_*` | 启动时各执行一次 / 解压 | SECURITY.md 已披露 |

---

## v1.0.2 (2026-11-24)

**首次包含重新编译的二进制。**

- `k100-miner` md5 `ea683cbf8a27c0b5ba985573c6d4afa1`（31,337,376 B，新编译）
- `libpearl5.so` md5 `e464446c956c627f07990e291dbc42dd`（未变）

### 修复：`--help` 不再暴露无关参数

v1.0.0/1.0.1 的 `--help` 会显示 `--model` / `--served-model-name` /
`--tensor-parallel-size` / `--gpu-memory-utilization` / `--max-model-len` /
`--dtype` / `--trust-remote-code` / `--port` 共 8 个参数 —— 那是内部伪装
留下、且**代码里从未引用过**的死参数。公开版不需要伪装，已全部移除。

现在 `--help` 只有 7 个真实参数：`--account --m --n --k --attempts --dry-run --test-job`

### 修复：`stop.sh` 会误杀无关进程

v1.0.0/1.0.1 的 `stop.sh` 按 argv 子串匹配（`'k100-miner' in ' '.join(argv)`），
会误杀任何命令行里含这个词的进程 —— 包括用户的编辑器（`vim .../k100-miner`）、
`tail -f`、`grep`，以及别处同名程序。实测复现：连调用它的 shell 都被选中。

现在改为按 `/proc/<pid>/exe` 的真实路径精确匹配，只杀从本目录启动的进程。

### 修复：日志目录权限

`/var/log/vllm-fork` 之前是默认 755、日志 644（世界可读）。日志含矿池域名与算力，
多用户机器上等于公开「谁在挖、挖哪个池」。现在目录 700、日志 600。

### 新增：安装前依赖自检

v1.0.0/1.0.1 的 `install.sh` 不做任何检查，DTK 没装好也会「安装成功」，然后
启动时才莫名失败。现在安装前逐项检查并明确报错（不通过则**零安装**、退出码 2）：

```
DTK 26.04 目录 / hipcc / rocm-smi / 检测到的 K100_AI 卡数 / glibc ≥ 2.14 /
python3 / 包内文件完整性
```

### 修复：`start.sh` 不再硬编码路径

v1.0.0/1.0.1 的 `start.sh` 写死 `/opt/vllm-fork/k100-miner`，用户用
`DST=/别的/路径` 安装时启动器会用错路径。现在跟随安装时的 `DST` / `LOGDIR` / `DTK`。

### 实测（2026-11-24，K100 真机，单卡）

```
算力       71.0 – 71.6 TH/s
每 attempt 15.3 – 15.6 ms
授权       authorize id=3 result=True
devfee     [devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)
Traceback  0
钱包校验   解密后 sha256[:16] = 6050486ad79f79da（与内嵌校验和一致）
```

> 说明：`--help` 的清理验证需重新编译，因此 v1.0.2 的二进制与 v1.0.1 不同。
> `libpearl5.so` 未变。构建环境：K100（Kylin V10，gcc 7.3.0，glibc 2.28，
> Python 3.12.16，Nuitka 4.3.5）。

---

## v1.0.1 (2026-11-24)

**纯文档更新，二进制与 v1.0.0 完全相同。**

- `k100-miner` md5 `7d2a12e5eba0d7fd81aa15403ee0dded`（与 v1.0.0 一致，未重新编译）
- `libpearl5.so` md5 `e464446c956c627f07990e291dbc42dd`（与 v1.0.0 一致）

### 修复

- **包内四份 README 更新到最新版**（v1.0.0 包内是旧版，缺少校验指引）
- 包内 README 新增「Verify Your Download / 校验下载」节：
  说明权威 SHA256 在 Release 页面与仓库 README 里，并给出 `sha256sum` 命令
- 包内 README 明确标注「本文件是压缩包内的副本，仓库 README 始终是权威版本」

### 说明

- **包内 README 刻意不写包自身的 SHA256** —— 否则会构成自引用（改了 SHA256
  就改了包，改了包 SHA256 又变）。权威值只放在仓库 README 与 Release 正文里。
- 新增 `make_release.sh` 打包脚本（位于私有源码仓，不在公开仓），使发行包可复现：
  固定 `mtime` / 属主 / 排序，任何人重跑都能得到相同的 tar.gz

---

## v1.0.0 (2026-11-10)

首个公开发布版。

- 海光 K100_AI (gfx928) 单卡 72 TH/s，8 卡 620 TH/s（矿池口径）
- 每 attempt 15.38 ms，400 W/卡
- 开发者费用 2.0%（按时间配额，72 小时实测 1.991%）
- 开发者钱包加密内嵌 + SHA256 完整性校验（地址不以明文出现，README 只放指纹）
- 含 8 卡启动器（每卡绑不相交的 CPU 核，避免 GPU 被 CPU 侧拖累）

### 真机实测（2026-11-16，Kylin V10，8× K100_AI）

| 功耗 | 8 卡算力 | 温度 | 能效 |
|---|---|---|---|
| 200 W | 321 TH/s | 67–70 °C | 0.201 TH/W |
| **250 W** | **416 TH/s** | — | **0.208 TH/W**（最佳）|
| 350 W | 534 TH/s | — | 0.191 TH/W |
| **400 W** | **577 TH/s** | 77–81 °C | 0.180 TH/W |

单卡 73.9 TH/s（14.9 ms/attempt），19 accepted / 0 rejected，
开发者账户切换验证：**按本版代码的公式，2% 下第一次切换约需 2205 秒（≈37 分钟）用户时长** —— 首切时间 = `job_est / (p/(1-p))`，`job_est≈45s`、`p=0.02`。
早期文档写的「45 秒后切换」是错的（那对应的是 50% 费率，不是 2%）。
