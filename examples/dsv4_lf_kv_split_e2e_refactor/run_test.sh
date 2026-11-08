#!/usr/bin/env bash
# 评测主入口：构造题目 → 起服务 → 等健康 → 逐题评测 → 停服务。
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

OUT=${1:?usage: bash run_test.sh <fresh_output_dir>}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
export AUDIT_DIR="$OUT/audit"

trap 'kill -TERM "${SERVER_PID:-}" 2>/dev/null || true
echo
echo "输出目录: $OUT"
echo "  服务日志: $OUT/server.log"
echo "  评测日志: $OUT/eval.log"
echo "  计划日志: $OUT/plan.log"
echo "  结果目录: $OUT/results"
echo "  审计目录: $OUT/audit"
if [[ -f "$OUT/report.md" ]]; then echo "  测试报告: $OUT/report.md"; fi' EXIT

python3 -u "$HERE/gsm8k_aiv.py" plan \
  --train "$TRAIN_PATH" --test "$TEST_PATH" \
  --test-offset "$TEST_OFFSET" --num-questions "$NUM_QUESTIONS" \
  --model-path "$MODEL_PATH" --min-prompt-tokens "$MIN_PROMPT_TOKENS" \
  --max-shots "$MAX_SHOTS" --seed 0 \
  --output "$OUT/plan.json" > "$OUT/plan.log" 2>&1

bash "$HERE/run_server.sh" > "$OUT/server.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 "$STARTUP_TIMEOUT"); do
  if curl -sf "http://127.0.0.1:$PORT/health" > /dev/null; then break; fi
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/health" > /dev/null || { echo "server not ready, see $OUT/server.log"; exit 1; }

set +e
python3 -u "$HERE/gsm8k_aiv.py" eval \
  --plan "$OUT/plan.json" --audit-dir "$AUDIT_DIR" \
  --base-url "http://127.0.0.1:$PORT" --dp-rank "$DP_RANK" \
  --eviction-tokens "$EVICTION_TOKENS" --audit-timeout "$AUDIT_TIMEOUT" \
  --max-new-tokens "$MAX_NEW_TOKENS" \
  --output "$OUT/results" 2>&1 | tee "$OUT/eval.log"
EVAL_RC=${PIPESTATUS[0]}
set -e

python3 -u "$HERE/report.py" "$OUT" 2>&1 | tee "$OUT/report.log"
exit "$EVAL_RC"
