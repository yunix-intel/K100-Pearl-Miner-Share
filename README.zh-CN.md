[English](README.md) | **简体中文** | [한국어](README.ko.md) | [日本語](README.ja.md)

# K100 Pearl (PRL) 矿机

海光 K100_AI（gfx928 DCU）上的 Pearl (PRL) 挖矿软件。
**二进制发布，不含源码。**

---

## 📦 下载

**[➡️ 下载 v1.0.1](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/tag/v1.0.1)**

| | |
|---|---|
| 安装包 | `k100-miner-v1.0.1-linux-x64.tar.gz` |
| 大小 | 29.8 MB |
| SHA256 | `d8ed939d9ebc0cbe974dbb34af1cadf91df0863d78af3fc71eb83fbeb13a7f5a` |

```bash
wget https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.1/k100-miner-v1.0.1-linux-x64.tar.gz
sha256sum k100-miner-v1.0.1-linux-x64.tar.gz          # 必须与上面的 SHA256 一致
tar xzf k100-miner-v1.0.1-linux-x64.tar.gz
cd k100-miner-v1.0.1-linux-x64
sudo ./install.sh
```

> **本仓库只放文档。** 二进制只通过 [Releases 页面](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases) 发布，我们不发布任何镜像。

---


> ## ⚠️ 开发者费用说明 —— 请先阅读再使用
>
> **本软件将 2.0% 的挖矿时间用于开发者。**
>
> | | |
> |---|---|
> | **比例** | **2.0%**，严格按*时间*结算（72 小时模拟：1.991%）|
> | **开发者钱包** | **加密内嵌在二进制里，任何地方都不出现明文** |
> | **钱包指纹** | `sha256:6050486ad79f`（前 12 位十六进制）|
> | **启动时** | 打印 `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)` |
> | **运行中** | 每次切换账户都打印累计比例，你可以核对它是否稳定在 2.0% 附近 |
> | **关闭方式** | `DEV_FEE_PERMILLE=0`（自测用；关闭后不向开发者付费）|
>
> ### 关于可验证性的诚实说明
>
> 因为钱包地址**不以明文公开**，**你无法独立验证这 2% 最终流向哪个钱包。**
>
> 你**能**验证的是：**比例确实是 2.0%**（从日志里的累计统计看）。
>
> **如果你需要可验证的收款方地址，请不要使用本软件。**
>
> **如果你不接受这个比例，或不接受"收款方不公开"，请不要使用本软件。**

---

## 目录

- [📦 下载](#-下载)
- [这是什么](#这是什么)
- [环境要求](#环境要求)
- [安装](#安装)
- [使用](#使用)
- [查看状态](#查看状态)
- [停止](#停止)
- [开发者费用的实现原理](#开发者费用的实现原理)
- [常见问题](#常见问题)
- [排错](#排错)
- [版本与许可](#版本与许可)

---

## 这是什么

在 8 卡海光 K100_AI 上跑 Pearl 挖矿的完整方案。
实测 **620 TH/s**（8 卡，矿池记账口径）。

| 项 | 数值 |
|---|---|
| 单卡算力 | 72 TH/s |
| 8 卡合计 | 620 TH/s（矿池显示值；随滚动窗口填充而爬升）|
| 每 attempt | 15.38 ms |
| 功耗 | 400 W/卡（`power1_cap_max` 硬件封顶）|
| 温度 | Tj 78–82 °C |

> **⚠️ 矿池显示的算力 ≈ 真实值 × (已运行分钟数 / 60)。**
> 刚启动时只有约三分之一，跑满一小时才准确。

### 工作原理（高层）

```
1. 从矿池解析 job（header + target）并派生 job key
2. 在 GPU 上生成 A/B 噪声矩阵
3. 每次 attempt：准备 A 侧选择集，然后跑 MMA kernel
4. 命中时：本地构造 proof（复用 GPU 算好的 chunk CV）并提交
5. 矿池每 ~43 秒发新 job；B 侧按 job 缓存（reuse-B）
```

---

---

## 下载后请校验

**本仓库的 Release 页面是唯一官方发布渠道**，我们没有镜像。

```bash
sha256sum k100-miner-v1.0.1-linux-x64.tar.gz
```

v1.0.1 的正确值：

```
d8ed939d9ebc0cbe974dbb34af1cadf91df0863d78af3fc71eb83fbeb13a7f5a
```

**校验值对不上就不要运行。** 说明包被人改过。删掉，从 Release 页面重新下载。

完整的完整性策略、以及如何举报「假包」，见 [SECURITY.md](SECURITY.md)。

## 环境要求

| 项 | 要求 |
|---|---|
| **硬件** | 海光 K100_AI（gfx928）DCU，建议 8 卡 |
| **驱动** | 海光 DTK **26.04**（`/opt/dtk/dtk-26.04`）|
| **系统** | Linux x86_64，glibc 2.28+ |
| **内存** | ≥ 16 GB |
| **磁盘** | ≥ 200 MB 可用 |
| **网络** | 能出站连矿池 TCP 8048 |
| **权限** | root（安装到 `/opt/vllm-fork`）|

### 支持的矿池

```
prl-hk.kryptex.network:8048   (TLS, type:v2 / gzip proof)
```

> 矿池端点已编译进程序。只有账户（`--account WALLET/WORKER`）由你提供。

---

## 安装

### 第 1 步 —— 确认 DTK 已装

```bash
ls /opt/dtk/dtk-26.04/bin/hipcc    # 必须存在
/opt/dtk/dtk-26.04/bin/rocm-smi    # 必须能列出 8 张 K100_AI
```

**不通过就先装海光 DTK 26.04。没有它程序不会启动。**

### 第 2 步 —— 解压

> 还没下载？见顶部 [📦 下载](#-下载)。


```bash
tar xzf k100-miner-v1.0.1-linux-x64.tar.gz
cd k100-miner-v1.0.1-linux-x64
```

内容：

```
k100-miner        主程序（单一可执行文件）
libpearl5.so      GPU kernel 库
install.sh        安装脚本
README.md         本文件
LICENSE           许可条款
CHANGELOG.md      变更记录
```

### 第 3 步 —— 安装

```bash
sudo ./install.sh
```

安装脚本会放置：

```
/opt/vllm-fork/k100-miner          主程序
/opt/vllm-fork/libpearl5.so        GPU 库
/opt/vllm-fork/start.sh            8 卡启动器（含 CPU 绑核）
/opt/vllm-fork/stop.sh             停止
/opt/vllm-fork/stat.sh             状态报告
/var/log/vllm-fork/                日志目录
```

验证安装：

```bash
ls -l /opt/vllm-fork/
/opt/vllm-fork/k100-miner --help
```

---

## 使用

### 单卡冒烟测试（先做这个）

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH

HIP_VISIBLE_DEVICES=0 /opt/vllm-fork/k100-miner \
    --account 你的钱包/你的worker \
    --m 8192 --n 65536 --k 2048
```

**10 秒内应看到：**

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

**✅ 看到 `authorize ... result=True` 和 `[mine]` 行 —— 正常工作。**

**❌ 如果 `target` 全是 0，或者没有 `[mine]` 行 —— 停下来看[排错](#排错)。**

### 8 卡生产

```bash
# 启动器会给每张卡绑 4 个不相交的逻辑 CPU 核
sudo /opt/vllm-fork/start.sh 你的钱包/你的worker
```

可选：覆盖功耗上限（默认 400 W，即硬件最大值）

```bash
POWER_W=350 sudo /opt/vllm-fork/start.sh 你的钱包/你的worker
```

### 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `--account` | **必填** | 你的矿池账户，格式 `钱包/worker` |
| `--m` | 8192 | A 矩阵行数（128 的倍数）|
| `--n` | 65536 | B 矩阵列数（128 的倍数）|
| `--k` | 2048 | 公共维（32 的倍数；≥ 16 × rank = 2048）|
| `--attempts` | 0 | 挖多少次后退出；0 = 无限 |
| `--dry-run` | off | 不真提交，只打印 |
| `--test-job` | off | **不连矿池**，用 `target = 0` 的假 job |

> **⚠️ 真实挖矿绝不能带 `--test-job`。** 它挖的是假 job（`target = 0`，
> 命中概率为 0），矿池会显示你离线，你一分钱都拿不到。

### 环境变量

| 变量 | 说明 |
|---|---|
| `HIP_VISIBLE_DEVICES` | 选卡，如 `0` 或 `0,1,2,3` |
| `DEV_FEE_PERMILLE` | 开发者费用（千分之一，默认 `20` = 2.0%）。`0` 关闭 |
| `LD_LIBRARY_PATH` | 必须包含 `/opt/dtk/dtk-26.04/lib64` |

### 正常性能长什么样

| 指标 | 期望值 |
|---|---|
| 每 attempt | 15.0 – 16.5 ms |
| 单卡 | 68 – 73 TH/s |
| 8 卡 | 550 – 580 TH/s（本地实测）|
| 功耗 | 400 W 档下约 395 – 400 W/卡 |
| Tj | 78 – 82 °C |

---

## 查看状态

```bash
/opt/vllm-fork/stat.sh
```

输出示例：

```
=== 各卡算力 ===
  gpu0   72.1 TH/s
  gpu1   71.8 TH/s
  ...
  ═══════════════
  合计 574 TH/s

=== share ===
  HIT=386   接受=383   拒绝=3

=== devfee 状态 ===
  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 2 次
```

### 手动检查

```bash
# 真的连上矿池了吗
grep 'authorize id=3 result=True' /var/log/vllm-fork/gpu0.log | head -1

# share 记账
grep -c '\[HIT\]'       /var/log/vllm-fork/gpu*.log
grep -c 'result=True'   /var/log/vllm-fork/gpu*.log
grep -c 'result=False'  /var/log/vllm-fork/gpu*.log

# 开发者费用 —— 核对是否稳定在 2.0%
grep 'devfee' /var/log/vllm-fork/gpu*.log | tail -5
```

> **关于矿池显示的算力：** 它是约 60 分钟的滚动平均。
> 刚启动只能看到真实值的约 1/3。**这是正常的**，不代表 share 丢了。

---

## 停止

```bash
sudo /opt/vllm-fork/stop.sh
```

然后确认：

```bash
ps -ef | grep -c '[k]100-miner'    # 应为 0
```

---

## 开发者费用的实现原理

**我们不隐瞒这件事。以下是完整机制。**

### 1. 按时间配额，不按 share 数量

```
每为你挖 49 秒，就欠开发者 1 秒（2%）
用公式 need = user_s × p/(1−p) 保证长期比例无偏
```

两种朴素做法都不对：

- 「欠了就切」会严重超付（用户挖 1 个 job 后立刻给 dev 一整段 ⇒ 约 50%）
- 「用 dev 秒数递减」会欠付（dev 段自身该欠的没算进去）

### 2. 只在 job 边界切换

```
矿池每 ~43 秒发新 job。切到开发者账户时会重新 authorize，日志里能看到：

  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 1 次
```

### 3. 钱包加密内嵌

```
开发者钱包不是明文常量，而是 XOR 加密的密文 + SHA256 完整性校验。

- 用 `strings` 在二进制里搜不到任何地址片段
- 改密文或校验和的任何一个字节 ⇒ 启动时 exit code 3
```

### 4. 你能验证什么、不能验证什么

| | |
|---|---|
| ✅ **能验证** | 比例确实是 2.0%（从日志的累计统计看）|
| ❌ **不能验证** | 钱最终进哪个钱包（地址不公开）|

**⇒ 如果你要求收款方地址可验证，请不要使用本软件。**

---

## 常见问题

### Q1. `libpearl5.so: cannot open shared object file`

GPU 库不在 `/opt/vllm-fork/libpearl5.so`。
重跑 `sudo ./install.sh`，或手动把 `libpearl5.so` 拷过去。

### Q2. `hipGetDeviceCount() = 0`

`LD_LIBRARY_PATH` 缺 `lib64` 目录：

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH
```

### Q3. 矿池显示离线 / 算力为 0

1. 确认日志里有 `authorize ... result=True`
2. 确认 `--account` 是 `钱包/worker`（中间是斜杠）
3. **确认没带 `--test-job`** —— 它挖假 job，矿池什么都看不到

### Q4. `integrity check failed` 然后退出

内嵌的开发者钱包 SHA256 校验失败 —— 二进制被改过了。
请从官方发布页重新下载。

### Q5. 功耗只到 280 W，算力偏低

用 `start.sh` 启动，别手工起 —— 它给每张卡绑 4 个不相交的逻辑 CPU 核，
避免 GPU 被 CPU 侧的准备工作饿死。这一项就对应 280 W → 399 W。

### Q6. 能改开发者费用比例吗

`DEV_FEE_PERMILLE=0` 可关闭。其他值也生效（`=10` 是 1%）。
**改比例不影响钱包的完整性校验。**

### Q7. 能少插几张卡吗

能。`HIP_VISIBLE_DEVICES=0,1` 就是 2 卡。算力大致线性缩放。

### Q8. 为什么矿池显示比 `stat.sh` 低

矿池是约 60 分钟滚动平均。另外注意：矿池按 1 hash = 1 MAC（M·N·K）记账，
而有些工具报 2·M·N·K（MADD），差 2 倍。本矿工记录的是 MAC 口径，与矿池一致。

---

## 排错

### 完全没有任何输出

```bash
/opt/vllm-fork/k100-miner --help     # 二进制本身能跑吗
ldd /opt/vllm-fork/k100-miner        # 动态库都解析了吗
```

### `authorize ... result=False`

账户串写错了。必须严格是 `钱包/worker`
（kryptex 线上协议用 `wallet.worker`，矿工负责把斜杠换掉）。

### share 被接受但 `result=False` 偏高（> 6%）

share 过期了。矿池每 ~43 秒换 job，矿工每 50 次 attempt 轮询新 job。
少量拒绝（< 6%）是正常的。如果明显偏高，检查到矿池的网络延迟。

### 温度超过 90 °C

降低功耗上限：

```bash
POWER_W=300 sudo /opt/vllm-fork/start.sh 你的钱包/你的worker
```

> 这张卡的 `power1_cap_max` 是 400 W，超过会被驱动拒绝。

### 日志在哪

```
/var/log/vllm-fork/gpu0.log … gpu7.log
```

---

## 版本与许可

见 [CHANGELOG.md](CHANGELOG.md) 与 [LICENSE](LICENSE)。

**仅二进制分发，不提供源码。**

许可禁止逆向工程、修改完整性校验、移除开发者费用机制。

| 版本 | 日期 | 说明 |
|---|---|---|
| 1.0.1 | 2026-11-24 | 文档更新，二进制未变（md5 `7d2a12e5`）。包内 README 更新；新增 `make_release.sh` 可复现打包。|
| 1.0.0 | 2026-11-10 | 首个二进制发布版。单卡 72 TH/s，8 卡 620 TH/s。开发者费用 2.0%。|
