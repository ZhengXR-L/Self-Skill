---
name: sglang-single-request
description: Launch an SGLang server on NPU and send one request to confirm basic inference works, using a single self-contained smoke script. Use when 用户要确认模型能起来能出字、排查启动失败，or asks for a first-request check. Do not use for 精度、性能或 PR 流程。
---

# SGLang 单请求冒烟测试

最小闭环：起一个服务、发一个请求、确认返回了非空生成文本。用于刚换模型、刚编译完、刚改完启动参数后确认「能起来、能出字」。

精度验证走 GSM8K 规范，性能对比走 benchmark 规范，本规范不涉及。

## 交付物结构

```text
<smoke_test>/
├── env.sh          # 必需：唯一配置入口
├── run_server.sh   # 必需：完整 sglang serve 命令
└── run_smoke.sh    # 必需：起服务 → 等就绪 → 发请求 → 停服务
```

## 硬性要求

1. 模型路径、后端、端口、显存比例、生成长度全部在 `env.sh` 定义，脚本里不出现个人目录或写死的绝对路径。
2. 服务统一用 `sglang serve`，不加 `exec`；由 `run_smoke.sh` 后台启动并转发 TERM。
3. 一个入口脚本完成全流程：`bash run_smoke.sh`，不需要另开终端手工起服务。
4. 发请求前必须等 `/health` 返回成功，不能只 `sleep` 固定秒数。
5. `temperature` 取 0，保证同样输入得到同样输出；不断言具体文本内容，只断言非空。
6. 退出时（成功、失败、Ctrl-C）打印服务日志、响应文件、退出码的路径。

## env.sh

```bash
#!/usr/bin/env bash
# 唯一配置入口。按实际环境修改标记为「需修改」的默认值。

export MODEL_PATH="${MODEL_PATH:-/home/weights/Qwen3-0.6B}"   # 需修改
export SGLANG_ROOT="${SGLANG_ROOT:-/path/to/sglang}"          # 需修改
export KERNEL_ROOT="${KERNEL_ROOT:-/path/to/sgl-kernel-npu}"  # 需修改

export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-7777}"
export DEVICE="${DEVICE:-npu}"
export ATTENTION_BACKEND="${ATTENTION_BACKEND:-ascend}"
export MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.75}"
export TP_SIZE="${TP_SIZE:-1}"
export STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-1800}"

export PROMPT="${PROMPT:-The capital of France is}"
export MAX_NEW_TOKENS="${MAX_NEW_TOKENS:-32}"
export OUT_DIR="${OUT_DIR:-$PWD/smoke_out}"

# Ascend 运行环境；脚本会引用未定义变量，source 期间临时关闭 -u。
set +u
source /usr/local/Ascend/ascend-toolkit/latest/set_env.sh
set -u

export PYTHONPATH="$SGLANG_ROOT/python:$KERNEL_ROOT/python/sgl_kernel_npu${PYTHONPATH:+:$PYTHONPATH}"
```

## run_server.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

sglang serve \
  --model-path "$MODEL_PATH" \
  --device "$DEVICE" \
  --attention-backend "$ATTENTION_BACKEND" \
  --tp-size "$TP_SIZE" \
  --mem-fraction-static "$MEM_FRACTION_STATIC" \
  --host "$HOST" --port "$PORT" &
SERVER_PID=$!
trap 'kill -TERM "$SERVER_PID" 2>/dev/null || true' TERM INT
wait "$SERVER_PID"
```

## run_smoke.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

mkdir -p "$OUT_DIR"
trap 'kill -TERM "${SERVER_PID:-}" 2>/dev/null || true
echo "输出目录: $OUT_DIR"
echo "  服务日志: $OUT_DIR/server.log"
echo "  请求体: $OUT_DIR/request.json"
echo "  响应文件: $OUT_DIR/response.json"' EXIT

bash "$HERE/run_server.sh" > "$OUT_DIR/server.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 "$STARTUP_TIMEOUT"); do
  if curl -sf "http://$HOST:$PORT/health" > /dev/null; then break; fi
  sleep 1
done
curl -sf "http://$HOST:$PORT/health" > /dev/null || { echo "服务未就绪，见 $OUT_DIR/server.log"; exit 1; }

python3 - "$OUT_DIR/request.json" <<'PY'
import json, os, sys
json.dump({"text": os.environ["PROMPT"],
           "sampling_params": {"temperature": 0,
                               "max_new_tokens": int(os.environ["MAX_NEW_TOKENS"])}},
          open(sys.argv[1], "w"))
PY

curl --fail-with-body --silent --show-error \
  "http://$HOST:$PORT/generate" \
  -H 'Content-Type: application/json' \
  -d @"$OUT_DIR/request.json" \
  -o "$OUT_DIR/response.json"

python3 - "$OUT_DIR/response.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
text = data.get("text")
print("生成结果:", repr(text))
print("结束原因:", data.get("meta_info", {}).get("finish_reason"))
sys.exit(0 if text else 1)
PY
```

## 请求格式

| 项 | 说明 |
| --- | --- |
| 接口 | `POST /generate`，原生接口；OpenAI 兼容接口为 `/v1/chat/completions` |
| `text` | 待续写文本，示例为 `The capital of France is` |
| `temperature` | 固定 `0`，便于复现 |
| `max_new_tokens` | 生成长度上限，冒烟测试用小值即可 |
| 判定 | HTTP 2xx 且响应 `text` 非空 |

断言不比对具体内容：换模型、换量化、换后端都会改变输出文本，固定答案会让冒烟测试变成脆弱的回归测试。

## 排查顺序

| 现象 | 先看 |
| --- | --- |
| 等不到 `/health` | `$OUT_DIR/server.log` 中模型加载与后端初始化日志 |
| 服务立即退出 | 参数拼写、`--attention-backend` 是否被当前版本支持、模型路径是否存在 |
| 请求 4xx | 请求体字段、`max_new_tokens` 是否为整数、模型是否已加载完成 |
| 请求 5xx | 服务日志末尾的堆栈，通常是显存或算子不支持 |
| 端口占用 | 改 `env.sh` 的 `PORT`，不要改脚本 |

## 结果记录

记录代码版本、模型、NPU 型号与卡数、启动命令、请求体、HTTP 状态、生成文本与 `finish_reason`。未实际执行时必须写「未运行」及原因。

## 检查清单

- [ ] 模型路径、端口、后端、显存比例、生成长度都在 `env.sh`
- [ ] `run_server.sh` 用 `sglang serve`，无 `exec`，参数与文档一致
- [ ] `run_smoke.sh` 一条命令完成起服务、等健康、发请求、停服务
- [ ] 等待条件是 `/health`，不是固定 `sleep`
- [ ] `temperature` 为 0，判定只看 `text` 非空
- [ ] 退出时打印日志与响应文件路径
