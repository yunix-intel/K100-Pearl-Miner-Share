#!/bin/bash
# K100 Pearl 矿机安装脚本
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
DST=${DST:-/opt/vllm-fork}

echo "════ K100 Pearl 矿机安装 ════"
[ "$(id -u)" -eq 0 ] || { echo "  ❌ 需要 root（用 sudo）"; exit 1; }

echo "  → 目标目录 $DST"
mkdir -p "$DST" /var/log/vllm-fork

for f in k100-miner libpearl5.so; do
  [ -f "$SRC/$f" ] || { echo "  ❌ 缺 $f"; exit 1; }
  install -m755 "$SRC/$f" "$DST/$f"
  echo "  ✅ $f"
done

# 8 卡启动器（含每卡不相交的 CPU 绑核）
cat > "$DST/start.sh" <<'EOS'
#!/bin/bash
# 8 卡启动器：每卡一组【不相交】的 4 逻辑线程
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:${LD_LIBRARY_PATH:-}
ACCT="${1:-}"
[ -n "$ACCT" ] || { echo "用法: $0 <钱包/worker>"; exit 1; }
POWER_W="${POWER_W:-400}"
SMI=/opt/dtk/dtk-26.04/bin/rocm-smi
[ -x "$SMI" ] && yes | $SMI --setpoweroverdrive "$POWER_W" >/dev/null 2>&1 && echo "  功耗上限 ${POWER_W}W"

declare -A CPU=(
  [0]="40,41,104,105"  [1]="42,43,106,107"  [2]="44,45,108,109"  [3]="46,47,110,111"
  [4]="32,33,96,97"    [5]="34,35,98,99"    [6]="48,49,112,113"  [7]="50,51,114,115"
)
mkdir -p /var/log/vllm-fork
for g in 0 1 2 3 4 5 6 7; do
  HIP_VISIBLE_DEVICES=$g nohup nice -n 10 ionice -c2 -n7 taskset -c "${CPU[$g]}" \
    /opt/vllm-fork/k100-miner --account "$ACCT" --m 8192 --n 65536 --k 2048 \
    > /var/log/vllm-fork/gpu$g.log 2>&1 &
  echo "  GPU$g pid=$!"
  sleep 1
done
EOS

cat > "$DST/stop.sh" <<'EOS'
#!/bin/bash
python3 - <<'PY'
import glob, os, signal, time
me = os.getpid(); k = []
for p in glob.glob('/proc/[0-9]*'):
    pid = int(p.split('/')[-1])
    if pid == me: continue
    try: argv = [a.decode() for a in open(f'{p}/cmdline','rb').read().split(b'\0') if a]
    except: continue
    if len(argv) >= 2 and 'k100-miner' in ' '.join(argv):
        try: os.kill(pid, signal.SIGTERM); k.append(pid)
        except: pass
print(f"  SIGTERM {len(k)} 个")
time.sleep(4)
PY
EOS

cat > "$DST/stat.sh" <<'EOS'
#!/bin/bash
echo "=== 各卡算力 ==="
TOT=0
for g in 0 1 2 3 4 5 6 7; do
  V=$(grep -oE 'MAC [0-9.]+ TH/s' /var/log/vllm-fork/gpu$g.log 2>/dev/null | grep -oE '[0-9.]+' | tail -10 | awk '{s+=$1;n++} END{printf "%.1f",(n?s/n:0)}')
  printf "  gpu%s %6s TH/s\n" "$g" "${V:-0}"
  TOT=$(python3 -c "print($TOT+${V:-0})")
done
python3 -c "print(f'  ═══════════════\n  合计 {$TOT:.0f} TH/s')"
echo ""
echo "=== share ==="
echo "  HIT=$(grep -hc '\[HIT\]' /var/log/vllm-fork/gpu*.log 2>/dev/null|paste -sd+|bc 2>/dev/null||echo 0)"
echo "  接受=$(grep -hc 'result=True' /var/log/vllm-fork/gpu*.log 2>/dev/null|paste -sd+|bc 2>/dev/null||echo 0)"
echo "  拒绝=$(grep -hc 'result=False' /var/log/vllm-fork/gpu*.log 2>/dev/null|paste -sd+|bc 2>/dev/null||echo 0)"
echo ""
echo "=== devfee 状态（每个进程）==="
grep -h 'devfee' /var/log/vllm-fork/gpu*.log 2>/dev/null | tail -4
EOS

chmod 755 "$DST/start.sh" "$DST/stop.sh" "$DST/stat.sh"
echo "  ✅ start.sh / stop.sh / stat.sh"
echo ""
echo "  ⚠️ 提醒：本软件会把 2.0% 的挖矿时间用于开发者（钱包指纹 sha256:6050486ad79f）"
echo "           启动日志第一行会打印这一行，可用矿池后台核对。"
echo ""
echo "════ 安装完成 ════"
echo "  启动: sudo $DST/start.sh 你的钱包/K100"
echo "  状态: $DST/stat.sh"
echo "  停止: sudo $DST/stop.sh"
