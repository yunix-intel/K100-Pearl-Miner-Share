#!/bin/bash
# K100 Pearl (PRL) 矿机安装脚本
#
# v1.0.2 修改：
#   · 新增依赖自检（DTK / rocm-smi / GPU / glibc）—— 不满足就明确报错，不装一半
#   · 日志目录改为 700、日志文件 600（含矿池域名，不该让普通用户读）
#   · stop.sh 改为按 /proc/<pid>/exe 精确匹配（旧版按 argv 子串匹配会误杀
#     编辑器 / tail / grep 等无关进程）
#   · start.sh 不再硬编码 /opt/vllm-fork（跟随 DST）
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
DST=${DST:-/opt/vllm-fork}
LOGDIR=${LOGDIR:-/var/log/vllm-fork}
DTK=${DTK:-/opt/dtk/dtk-26.04}

echo "════ K100 Pearl (PRL) 矿机安装 ════"
[ "$(id -u)" -eq 0 ] || { echo "  ❌ 需要 root（用 sudo）"; exit 1; }

# ── 1. 依赖自检（缺什么提前说，不要装到一半才炸）──
echo ""
echo "  ── 依赖自检 ──"
FAIL=0
chk() {
  local name="$1" ok="$2" hint="$3"
  if [ "$ok" = "1" ]; then echo "  ✅ $name"; else echo "  ❌ $name —— $hint"; FAIL=1; fi
}

# DTK
if [ -d "$DTK" ]; then chk "DTK 26.04（$DTK）" 1 ""; else
  chk "DTK 26.04（$DTK）" 0 "先装海光 DTK 26.04，或用 DTK=/path 指定"
fi

# hipcc
if [ -x "$DTK/bin/hipcc" ]; then chk "hipcc" 1 ""; else
  chk "hipcc" 0 "DTK 安装不完整（$DTK/bin/hipcc 不存在）"
fi

# rocm-smi
if [ -x "$DTK/bin/rocm-smi" ]; then
  chk "rocm-smi" 1 ""
  NPU=$("$DTK/bin/rocm-smi" 2>/dev/null | grep -cE '^[0-9]+[[:space:]]' || true)
  NPU=${NPU:-0}
  if [ "$NPU" -ge 1 ]; then
    chk "检测到 $NPU 张 K100_AI (gfx928)" 1 ""
    [ "$NPU" -lt 8 ] && echo "     ⚠️  不足 8 张（单卡也能跑，只是算力按比例）"
  else
    chk "检测到 K100_AI 显卡" 0 "rocm-smi 列不出卡：检查驱动 / 是否装了别的 GPU"
  fi
else
  chk "rocm-smi" 0 "DTK 安装不完整"
fi

# glibc（二进制要求 ≥ 2.14）
# 注意：这里不能用 `| head -1` —— set -o pipefail 下 ldd 会收到 SIGPIPE(141)，
# 导致 `|| echo 0` 追加一行，版本号变成 "2.34\n0"。用 awk 读全量避免。
GLIBC_VER=$(ldd --version 2>/dev/null | awk 'NR==1{print $NF}')
if [ -n "$GLIBC_VER" ] && awk -v v="$GLIBC_VER" 'BEGIN{exit !(v+0 >= 2.14)}'; then
  chk "glibc $GLIBC_VER（需要 ≥ 2.14）" 1 ""
else
  chk "glibc ${GLIBC_VER:-未知}（需要 ≥ 2.14）" 0 "系统太旧，二进制跑不起来"
fi

# python3（stop.sh / stat.sh 用）
if command -v python3 >/dev/null 2>&1; then chk "python3" 1 ""; else
  chk "python3" 0 "stop.sh / stat.sh 依赖 python3"
fi

# 包内文件
for f in k100-miner libpearl5.so; do
  if [ -f "$SRC/$f" ]; then chk "包内 $f" 1 ""; else chk "包内 $f" 0 "安装包不完整，重新解压"; fi
done

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "  ❌ 依赖检查未通过，已中止（什么都没装）。修好后重跑。"
  exit 2
fi
echo "  ✅ 依赖检查全部通过"

# ── 2. 安装二进制 ──
echo ""
echo "  → 目标目录 $DST"
mkdir -p "$DST"
install -m755 "$SRC/k100-miner"    "$DST/k100-miner"
install -m755 "$SRC/libpearl5.so"  "$DST/libpearl5.so"
echo "  ✅ k100-miner / libpearl5.so"

# 日志目录：700（含矿池域名与算力，不该让普通用户读）
mkdir -p "$LOGDIR"
chmod 700 "$LOGDIR"
echo "  ✅ 日志目录 $LOGDIR（700）"

# ── 3. 生成启动器 ──
# 注意：下面用未加引号的 heredoc，才能在生成时把 $DST/$LOGDIR/$DTK 写死进去
cat > "$DST/start.sh" <<EOS
#!/bin/bash
# 8 卡启动器：每卡一组【不相交】的 4 逻辑线程
# 由 install.sh 生成，安装路径：$DST
export LD_LIBRARY_PATH=$DTK/lib64:$DTK/lib:\${LD_LIBRARY_PATH:-}
ACCT="\${1:-}"
[ -n "\$ACCT" ] || { echo "用法: \$0 <钱包/worker>"; exit 1; }
POWER_W="\${POWER_W:-400}"
SMI=$DTK/bin/rocm-smi
BIN=$DST/k100-miner
LOGDIR=$LOGDIR

[ -x "\$BIN" ]         || { echo "  ❌ 找不到 \$BIN"; exit 1; }
[ -f "\$LOGDIR" ] && { echo "  ❌ \$LOGDIR 是文件，不是目录"; exit 1; }
mkdir -p "\$LOGDIR"; chmod 700 "\$LOGDIR" 2>/dev/null

if [ -x "\$SMI" ]; then
  yes | "\$SMI" --setpoweroverdrive "\$POWER_W" >/dev/null 2>&1 \\
    && echo "  功耗上限 \${POWER_W}W" \\
    || echo "  ⚠️  设置功耗上限失败（继续，用默认功耗）"
fi

declare -A CPU=(
  [0]="40,41,104,105"  [1]="42,43,106,107"  [2]="44,45,108,109"  [3]="46,47,110,111"
  [4]="32,33,96,97"    [5]="34,35,98,99"    [6]="48,49,112,113"  [7]="50,51,114,115"
)
NCARD=\$("\$SMI" 2>/dev/null | grep -cE '^[0-9]+[[:space:]]' || echo 0)
[ "\${NCARD:-0}" -ge 1 ] || NCARD=8

for g in \$(seq 0 \$((NCARD-1))); do
  LOG="\$LOGDIR/gpu\$g.log"
  : > "\$LOG"; chmod 600 "\$LOG" 2>/dev/null
  HIP_VISIBLE_DEVICES=\$g nohup nice -n 10 ionice -c2 -n7 taskset -c "\${CPU[\$g]:-0}" \\
    "\$BIN" --account "\$ACCT" --m 8192 --n 65536 --k 2048 \\
    >> "\$LOG" 2>&1 &
  echo "  GPU\$g pid=\$! cpu=\${CPU[\$g]:-0}"
  sleep 1
done
echo ""
echo "  已启动 \$NCARD 个进程；日志 \$LOGDIR/gpuN.log"
EOS

# ── 4. 生成停止脚本（精确匹配 exe，不误杀）──
cat > "$DST/stop.sh" <<EOS
#!/bin/bash
# 停止所有从 $DST/k100-miner 启动的进程
# 匹配依据：/proc/<pid>/exe 的真实路径（不是 argv 子串 —— 那会误杀编辑器 / tail / grep）
BIN=$DST/k100-miner
exec python3 - "\$BIN" <<'PY'
import glob, os, signal, sys, time
target = os.path.realpath(sys.argv[1])
me = os.getpid()
killed, seen = [], 0
for p in glob.glob('/proc/[0-9]*'):
    pid = int(p.split('/')[-1])
    if pid == me: continue
    try:
        exe = os.readlink(f'{p}/exe')
    except OSError:
        continue
    seen += 1
    # 二进制被删除后 readlink 会带 " (deleted)" 后缀
    if exe.endswith(' (deleted)'): exe = exe[:-10]
    if os.path.realpath(exe) != target: continue
    try:
        os.kill(pid, signal.SIGTERM); killed.append(pid)
    except OSError:
        pass
print(f"  SIGTERM {len(killed)} 个进程（匹配目标 {target}）")
if killed:
    for _ in range(20):
        time.sleep(0.25)
        alive = [p for p in killed if os.path.exists(f'/proc/{p}')]
        if not alive: break
    else:
        print("  ⚠️  仍有进程未退出，尝试 SIGKILL")
        for p in killed:
            try: os.kill(p, signal.SIGKILL)
            except OSError: pass
PY
EOS

# ── 5. 生成状态脚本 ──
cat > "$DST/stat.sh" <<EOS
#!/bin/bash
# 状态报告；读 $LOGDIR
LOGDIR=$LOGDIR
echo "=== 各卡算力 ==="
TOT=0
N=0
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
sum() { grep -hc "\$1" "\$LOGDIR"/gpu*.log 2>/dev/null | awk '{s+=\$1} END{print s+0}'; }
echo "  HIT=\$(sum '\\[HIT\\]')"
echo "  接受=\$(sum 'result=True')"
echo "  拒绝=\$(sum 'result=False')"
echo ""
echo "=== devfee 状态 ==="
grep -h 'devfee' "\$LOGDIR"/gpu*.log 2>/dev/null | tail -4
EOS

chmod 755 "$DST/start.sh" "$DST/stop.sh" "$DST/stat.sh"
echo "  ✅ start.sh / stop.sh / stat.sh"

echo ""
echo "  ⚠️  开发者费用：本软件会把 2.0% 的挖矿时间用于开发者（钱包指纹 sha256:6050486ad79f）"
echo "            启动日志会打印这一行，可用矿池后台核对。"
echo ""
echo "════ 安装完成 ════"
echo "  启动: sudo $DST/start.sh 你的钱包/K100"
echo "  状态: $DST/stat.sh"
echo "  停止: sudo $DST/stop.sh"