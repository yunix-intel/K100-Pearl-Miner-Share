# 变更记录

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
- 新增 `make_release.sh` 打包脚本，使发行包可复现：
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
45 秒后切到开发者账户，6 个 share 全部 `result=True`。
