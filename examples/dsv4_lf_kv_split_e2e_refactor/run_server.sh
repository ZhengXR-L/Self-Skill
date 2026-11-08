#!/usr/bin/env bash
# 专用 DeepSeek-V4 HiCache 服务；进程组由 run_test.sh 管理。
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

: "${AUDIT_DIR:?Set AUDIT_DIR to a fresh directory}"

# 审计 hook 必须位于 PYTHONPATH 最前，由 sitecustomize 自动安装。
BOOT="$AUDIT_DIR/boot"
mkdir -p "$BOOT"
cp "$HERE/aiv_audit_hook.py" "$BOOT/"
printf 'from aiv_audit_hook import install\ninstall()\n' > "$BOOT/sitecustomize.py"
export DSV4_GSM_AIV_AUDIT_DIR="$AUDIT_DIR"
export PYTHONPATH="$BOOT:$PYTHONPATH"

# 评测要求同名 launch.json 存在，同时记录被测代码版本。
python3 - "$AUDIT_DIR" <<'PY'
import json, os, subprocess, sys
rev = lambda p: subprocess.run(["git", "-C", p, "rev-parse", "HEAD"],
                               capture_output=True, text=True).stdout.strip()
json.dump({"argv": ["sglang", "serve"], "model_path": os.environ["MODEL_PATH"],
           "npu_devices": os.environ["NPU_DEVICES"], "port": os.environ["PORT"],
           "quantization": os.environ["QUANTIZATION"],
           "sglang_root": os.environ["SGLANG_ROOT"],
           "git_commit": rev(os.environ["SGLANG_ROOT"]),
           "kernel_root": os.environ["KERNEL_ROOT"],
           "kernel_commit": rev(os.environ["KERNEL_ROOT"])},
          open(os.path.join(sys.argv[1], "launch.json"), "w"), indent=2)
PY

if [[ -n "$QUANTIZATION" ]]; then
  quant_args=(--quantization "$QUANTIZATION")
else
  quant_args=()
fi

sglang serve \
  --model-path "$MODEL_PATH" \
  --host 127.0.0.1 --port "$PORT" --trust-remote-code \
  --tp-size 8 --ep-size 8 --dp-size 8 --enable-dp-attention --enable-dp-lm-head \
  --device npu --attention-backend dsv4 "${quant_args[@]}" --kv-cache-dtype bfloat16 \
  --page-size 128 --swa-full-tokens-ratio 0.1 --max-total-tokens 66000 \
  --max-running-requests 16 --chunked-prefill-size 32768 --mem-fraction-static 0.8 \
  --moe-a2a-backend deepep --deepep-mode auto --watchdog-timeout 9000 --random-seed 0 \
  --context-length 1048576 --cuda-graph-backend-prefill disabled \
  --cuda-graph-backend-decode disabled \
  --enable-hicache --hicache-mem-layout layer_first \
  --hicache-io-backend kernel_ascend --hicache-write-policy write_through \
  --hicache-ratio 2.5 &
SERVER_CHILD=$!

# 收到 TERM 时转发给服务进程，避免 run_test.sh 退出后服务残留。
trap 'kill -TERM "$SERVER_CHILD" 2>/dev/null || true' TERM INT
wait "$SERVER_CHILD"
