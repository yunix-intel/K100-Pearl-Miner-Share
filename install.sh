#!/bin/bash
# K100 Pearl (PRL) 矿机安装脚本
#
# v1.0.3 修改：
#   · stat.sh 统计修正：命中用 [MATCH]（原来 grep [HIT]，二进制从不打印）；
#     接受/拒绝只数 share 应答（原来把 authorize 也算成 share）
#   · start.sh 的 CPU 绑核改为按实际核数自适应（原来硬编码 32–115 号核，
#     少于 116 核的机器 taskset 直接失败）
#   · 覆盖已有文件前先备份到 <DST>.bak.<时间戳>，并明确提示
#   · 给 start.sh 设置 K100_LIB，保证二进制能找到 libpearl5.so
#   · 记录 /tmp 需要 8×123 MB（Nuitka onefile 会解压）
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
DST=${DST:-/opt/vllm-fork}
LOGDIR=${LOGDIR:-/var/log/vllm-fork}
DTK=${DTK:-/opt/dtk/dtk-26.04}
UF=${UMASK:-022}

echo "════ K100 Pearl (PRL) 矿机安装 ════"
[ "$(id -u)" -eq 0 ] || { echo "  ❌ 需要 root（用 sudo）"; exit 1; }

# ── 1. 依赖自检 ──
echo ""
echo "  ── 依赖自检 ──"
FAIL=0
chk() {
  local name="$1" ok="$2" hint="$3"
  if [ "$ok" = "1" ]; then echo "  ✅ $name"; else echo "  ❌ $name —— $hint"; FAIL=1; fi
}

if [ -d "$DTK" ]; then chk "DTK 26.04（$DTK）" 1 ""; else
  chk "DTK 26.04（$DTK）" 0 "先装海光 DTK 26.04，或用 DTK=/path 指定"
fi
if [ -x "$DTK/bin/hipcc" ]; then chk "hipcc" 1 ""; else
  chk "hipcc" 0 "DTK 安装不完整（$DTK/bin/hipcc 不存在）"
fi

if [ -x "$DTK/bin/rocm-smi" ]; then
  chk "rocm-smi" 1 ""
  NPU=$("$DTK/bin/rocm-smi" 2>/dev/null | grep -cE '^[0-9]+[[:space:]]' || true)
  NPU=${NPU:-0}
  if [ "$NPU" -ge 1 ]; then
    chk "检测到 $NPU 张 K100_AI (gfx928)" 1 ""
    [ "$NPU" -lt 8 ] && echo "     ⚠️  不足 8 张（单卡也能跑，算力按比例）"
  else
    chk "检测到 K100_AI 显卡" 0 "rocm-smi 列不出卡：检查驱动"
  fi
else
  chk "rocm-smi" 0 "DTK 安装不完整"
fi

# 注意：不能用 `| head -1` —— set -o pipefail 下 ldd 会收到 SIGPIPE(141)，
# 导致 `|| echo 0` 追加一行，版本号变成 "2.34\n0"。用 awk 读全量避免。
GLIBC_VER=$(ldd --version 2>/dev/null | awk 'NR==1{print $NF}')
if [ -n "$GLIBC_VER" ] && awk -v v="$GLIBC_VER" 'BEGIN{exit !(v+0 >= 2.14)}'; then
  chk "glibc $GLIBC_VER（需要 ≥ 2.14）" 1 ""
else
  chk "glibc ${GLIBC_VER:-未知}（需要 ≥ 2.14）" 0 "系统太旧，二进制跑不起来"
fi

if command -v python3 >/dev/null 2>&1; then chk "python3" 1 ""; else
  chk "python3" 0 "stop.sh / stat.sh 依赖 python3"
fi

for f in k100-miner libpearl5.so; do
  if [ -f "$SRC/$f" ]; then chk "包内 $f" 1 ""; else chk "包内 $f" 0 "安装包不完整，重新解压"; fi
done

# 磁盘：onefile 会把 ~123 MB 解压到 /tmp，8 卡同时跑约 8×123 MB
NCARD_HINT=$("$DTK/bin/rocm-smi" 2>/dev/null | grep -cE '^[0-9]+[[:space:]]' || true)
NCARD_HINT=${NCARD_HINT:-1}; [ "$NCARD_HINT" -ge 1 ] || NCARD_HINT=1
NEED_TMP=$(( NCARD_HINT * 130 ))
AVAIL_TMP=$(df -Pm /tmp 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "${AVAIL_TMP:-}" ] && [ "$AVAIL_TMP" -ge "$NEED_TMP" ]; then
  chk "/tmp 可用 ${AVAIL_TMP} MB（需要约 ${NEED_TMP} MB）" 1 ""
else
  chk "/tmp 可用 ${AVAIL_TMP:-?} MB（需要约 ${NEED_TMP} MB）" 0 "每个进程解压约 123 MB 到 /tmp，空间不足会失败"
fi

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "  ❌ 依赖检查未通过，已中止（什么都没装）。修好后重跑。"
  exit 2
fi
echo "  ✅ 依赖检查全部通过"

# ── 2. 覆盖前备份 ──
if [ -e "$DST/k100-miner" ] || [ -e "$DST/libpearl5.so" ]; then
  BAK="${DST}.bak.$(date +%Y%m%d_%H%M%S)"
  echo ""
  echo "  ⚠️  $DST 里已有同名文件，先备份到 $BAK"
  mkdir -p "$BAK"
  for f in k100-miner libpearl5.so start.sh stop.sh stat.sh; do
    [ -e "$DST/$f" ] && cp -p "$DST/$f" "$BAK/" 2>/dev/null || true
  done
  echo "  ✅ 备份完成（$(ls -1 "$BAK" 2>/dev/null | wc -l) 个文件）"
  echo "     如需还原：cp -p $BAK/* $DST/"
fi

# ── 3. 安装二进制 ──
echo ""
echo "  → 目标目录 $DST"
mkdir -p "$DST"; chmod 755 "$DST"
install -m755 "$SRC/k100-miner"    "$DST/k100-miner"
install -m755 "$SRC/libpearl5.so"  "$DST/libpearl5.so"
echo "  ✅ k100-miner / libpearl5.so"

mkdir -p "$LOGDIR"; chmod 700 "$LOGDIR"
echo "  ✅ 日志目录 $LOGDIR（700）"

# ── 4. 启动器 ──
# 未加引号的 heredoc：生成时把实际路径写进去
cat > "$DST/start.sh" <<EOS
#!/bin/bash
# 8 卡启动器：每卡一组不相交的逻辑 CPU 核
# 由 install.sh 生成，安装路径：$DST
export LD_LIBRARY_PATH=$DTK/lib64:$DTK/lib:\${LD_LIBRARY_PATH:-}
ACCT="\${1:-}"
[ -n "\$ACCT" ] || { echo "用法: \$0 <钱包/worker>"; exit 1; }
POWER_W="\${POWER_W:-400}"
SMI=$DTK/bin/rocm-smi
BIN=$DST/k100-miner
LOGDIR=$LOGDIR
export K100_LIB=$DST/libpearl5.so

[ -x "\$BIN" ] || { echo "  ❌ 找不到 \$BIN"; exit 1; }
mkdir -p "\$LOGDIR"; chmod 700 "\$LOGDIR" 2>/dev/null

if [ -x "\$SMI" ]; then
  yes | "\$SMI" --setpoweroverdrive "\$POWER_W" >/dev/null 2>&1 \\
    && echo "  功耗上限 \${POWER_W}W" \\
    || echo "  ⚠️  设置功耗上限失败（继续用默认功耗）"
fi

NCARD=\$("\$SMI" 2>/dev/null | grep -cE '^[0-9]+[[:space:]]')
[ "\${NCARD:-0}" -ge 1 ] || NCARD=8
NPROC=\$(nproc)

# 优先用调优过的绑核表（K100 在 192 核机器上实测最好）；核数不够就退化
declare -A CPU=(
  [0]="40,41,104,105"  [1]="42,43,106,107"  [2]="44,45,108,109"  [3]="46,47,110,111"
  [4]="32,33,96,97"    [5]="34,35,98,99"    [6]="48,49,112,113"  [7]="50,51,114,115"
)
MAXCPU=115
if [ "\$NPROC" -le "\$MAXCPU" ]; then
  echo "  ⚠️  这台机器只有 \$NPROC 个逻辑核（调优表需要 116 个），改用均匀分配"
  # 均匀分：每卡 4 个连续核
  for g in \$(seq 0 15); do CPU[\$g]=""; done
fi

for g in \$(seq 0 \$((NCARD-1))); do
  if [ -n "\${CPU[\$g]:-}" ]; then SET="\${CPU[\$g]}"; else
    BASE=\$(( (g * NPROC / NCARD) ))
    SET="\$BASE,\$((BASE+1)),\$((BASE+2)),\$((BASE+3))"
  fi
  LOG="\$LOGDIR/gpu\$g.log"
  : > "\$LOG"; chmod 600 "\$LOG" 2>/dev/null
  HIP_VISIBLE_DEVICES=\$g nohup nice -n 10 ionice -c2 -n7 taskset -c "\$SET" \\
    "\$BIN" --account "\$ACCT" --m 8192 --n 65536 --k 2048 \\
    >> "\$LOG" 2>&1 &
  echo "  GPU\$g pid=\$! cpu=\$SET"
  sleep 1
done
echo ""
echo "  已启动 \$NCARD 个进程；日志 \$LOGDIR/gpuN.log"
EOS

# ── 5. 停止脚本（按 exe 精确匹配）──
cat > "$DST/stop.sh" <<EOS
#!/bin/bash
# 停止所有从 $DST/k100-miner 启动的进程
# 依据 /proc/<pid>/exe 的真实路径，不用 argv 子串（那会误杀编辑器 / tail / grep）
BIN=$DST/k100-miner
exec python3 - "\$BIN" <<'PY'
import glob, os, signal, sys, time
target = os.path.realpath(sys.argv[1])
me = os.getpid()
killed = []
for p in glob.glob('/proc/[0-9]*'):
    pid = int(p.split('/')[-1])
    if pid == me:
        continue
    try:
        exe = os.readlink(f'{p}/exe')
    except OSError:
        continue
    if exe.endswith(' (deleted)'):
        exe = exe[:-10]
    if os.path.realpath(exe) != target:
        continue
    try:
        os.kill(pid, signal.SIGTERM)
        killed.append(pid)
    except OSError:
        pass
print(f"  SIGTERM {len(killed)} 个进程（目标 {target}）")
if killed:
    for _ in range(20):
        time.sleep(0.25)
        if not any(os.path.exists(f'/proc/{p}') for p in killed):
            break
    else:
        print("  ⚠️  仍有进程未退出，改用 SIGKILL")
        for p in killed:
            try:
                os.kill(p, signal.SIGKILL)
            except OSError:
                pass
PY
EOS

# ── 6. 状态脚本（标签与二进制一致）──
cat > "$DST/stat.sh" <<EOS
#!/bin/bash
# 状态报告。标签与二进制实际输出一致：
#   [compute] 每 attempt   [MATCH] 命中   [publish] 已提交   [transport] ◀ share 应答
LOGDIR=$LOGDIR
echo "=== 各卡算力 ==="
TOT=0; N=0
for f in "\$LOGDIR"/gpu*.log; do
  [ -f "\$f" ] || continue
  g=\$(basename "\$f" .log); g=\${g#gpu}
  V=\$(grep -oE 'MAC [0-9.]+ TH/s' "\$f" 2>/dev/null | grep -oE '[0-9.]+' | tail -10 \\
       | awk '{s+=\$1;n++} END{printf "%.1f",(n?s/n:0)}')
  printf "  gpu%s %6s TH/s\n" "\$g" "\${V:-0}"
  TOT=\$(awk -v a="\$TOT" -v b="\${V:-0}" 'BEGIN{printf "%.1f", a+b}')
  N=\$((N+1))
done
awk -v t="\$TOT" -v n="\$N" 'BEGIN{printf "  ═══════════════\n  合计 %.0f TH/s（%d 卡）\n", t, n}'
echo ""
echo "=== share ==="
cnt() { grep -h "\$1" "\$LOGDIR"/gpu*.log 2>/dev/null | grep -c "\$2" || true; }
echo "  命中(本地 MATCH)= \$(cnt '\\[MATCH\\] ★★★' '')"
echo "  已提交(publish)=  \$(cnt '\\[publish\\] job=' '')"
echo "  接受=             \$(cnt '◀ id=' 'result=True')"
echo "  拒绝=             \$(cnt '◀ id=' 'result=False')"
echo ""
echo "=== devfee 状态 ==="
grep -h 'devfee' "\$LOGDIR"/gpu*.log 2>/dev/null | tail -4
EOS

chmod 755 "$DST/start.sh" "$DST/stop.sh" "$DST/stat.sh"
echo "  ✅ start.sh / stop.sh / stat.sh"

echo ""
echo "  ⚠️  开发者费用：本软件会把 2.0% 的挖矿时间用于开发者（钱包指纹 sha256:6050486ad79f）"
echo "            启动日志第一行会打印这一行，可用矿池后台核对。"
echo "            注意：2% 下的第一次账户切换约需 37 分钟用户时长，不是 45 秒。"
echo ""
echo "  ℹ️  每个进程运行时会解压约 123 MB 到 /tmp（Nuitka onefile），属正常行为。"
echo ""
echo "════ 安装完成 ════"
echo "  启动: sudo $DST/start.sh 你的钱包/K100"
echo "  状态: $DST/stat.sh"
echo "  停止: sudo $DST/stop.sh"
[ -n "${BAK:-}" ] && echo "  还原: cp -p $BAK/* $DST/"