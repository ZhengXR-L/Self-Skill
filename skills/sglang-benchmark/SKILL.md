---
name: sglang-benchmark
description: Write and run SGLang serving performance benchmarks with sglang.bench_serving for TTFT, throughput, and prefix-cache scenarios. Use when 用户要测 TTFT、吞吐或做性能回归对比，or asks to compare serving performance. Do not use for 精度测试、单请求冒烟或 PR 格式。
---

# SGLang 性能测试规范

用 `sglang.bench_serving` 作为客户端压测工具，约束如何组织一次可复现、可对比的服务端性能测试。适用于任意模型，不绑定 DeepSeek-V4。

精度测试走 GSM8K 规范，功能验证走测试脚本规范，本规范只关心延迟与吞吐。

## 交付物结构

```text
<perf_test>/
├── README.md        # 必需：场景、参数、命令、结果判定
├── env.sh           # 必需：唯一配置入口
├── run_server.sh    # 必需：完整 sglang serve 命令
├── run_bench.sh     # 必需：bench_serving 客户端命令
└── report.py        # 必需：解析 jsonl 生成 report.md
```

## 硬性要求

### 1. 配置集中在 env.sh

模型、卡号、端口、数据集参数、并发、请求数、warmup、输出目录全部在 `env.sh` 中定义，并用 `${VAR:-default}` 允许覆盖。`run_server.sh`、`run_bench.sh` 只 `source`，不重复定义。

### 2. 服务端用 sglang serve

与测试脚本规范一致：`env.sh` 内 source Ascend 环境并导出 `ASCEND_RT_VISIBLE_DEVICES`，`run_server.sh` 直接 `sglang serve`，不加 `exec`，后台运行并转发 TERM。

### 3. 客户端只用 bench_serving

不自写压测循环、不用 curl 计时。所有延迟与吞吐以 `sglang.bench_serving` 的统计为准。

### 4. 固定可比变量

同一次对比中，以下变量必须完全一致，并在 README 中列出：模型与量化、服务端全部参数、数据集类型与长度分布、`num-prompts`、`max-concurrency`、`warmup-requests`、随机种子。只允许被测参数不同。

### 5. 至少 3 次运行取中位数

单次结果受调度与缓存状态影响大。同一场景连续跑 3 次，取中位数作为结论；波动超过 5% 时先排查机器与残留进程，不要直接下结论。

### 6. 先预热

`warmup-requests` 取并发数的 1–2 倍，不允许为 0。冷启动、图捕获、连接建立的耗时不能计入性能结论。

### 7. 留存原始数据

保留 `--output-details` 的 jsonl 与客户端日志。`report.py` 只做汇总，不重新计算延迟。

## 测试场景

| 场景 | 关注指标 | 关键参数 |
| --- | --- | --- |
| 单请求延迟 | TTFT、TPOT | `--max-concurrency 1`，输出长度 ≥128 |
| 共享前缀 / HiCache 命中 | TTFT、`cached_tokens_details` | `generated-shared-prefix` + `--gsp-ordered` |
| 吞吐 | output/request throughput | `--max-concurrency` 取目标并发，总请求数至少为并发数的 10 倍 |
| 长上下文 | TTFT、显存 | `gsp-question-len` 取目标长度，注意 `context-length` 上限 |

场景参数全部通过 `env.sh` 覆盖，不复制多份 `run_bench.sh`。

## bench_serving 常用参数

| 参数 | 含义 |
| --- | --- |
| `--backend sglang` | 后端类型，连接 SGLang 服务 |
| `--host` / `--port` | 服务地址；可与服务端分机部署 |
| `--model` | 服务端已加载的模型名或路径，需与服务端一致 |
| `--dataset-name` | `generated-shared-prefix`、`random`、`sharegpt`、自定义 |
| `--gsp-num-groups` / `--gsp-prompts-per-group` | 共享前缀组数与每组请求数 |
| `--gsp-question-len` / `--gsp-output-len` | 组内问题长度与输出长度 |
| `--gsp-ordered` | 按组顺序发送，用于测前缀复用 |
| `--random-input-len` / `--random-output-len` | `random` 数据集的长度 |
| `--num-prompts` | 总请求数，`random` / `sharegpt` 必填；`generated-shared-prefix` 由组数决定 |
| `--max-concurrency` | 并发上限，必须小于等于总请求数 |
| `--warmup-requests` | 预热请求数，不计入统计 |
| `--tokenize-prompt` | 由服务端分词，避免本地 tokenizer 差异 |
| `--cache-report` | 输出缓存命中明细，需配合 `--output-details` |
| `--output-details` | 保留逐请求明细 |
| `--output-file` | 结果 jsonl 路径 |
| `--extra-request-body` | 追加请求体字段，例如固定路由 `{"routed_dp_rank":0}` |

## 示例脚本

### env.sh

```bash
#!/usr/bin/env bash
# 唯一配置入口。按实际环境修改标记为「需修改」的默认值。

export MODEL_PATH="${MODEL_PATH:-/path/to/model}"       # 需修改
export MODEL_NAME="${MODEL_NAME:-$MODEL_PATH}"
export SGLANG_ROOT="${SGLANG_ROOT:-/path/to/sglang}"    # 需修改
export KERNEL_ROOT="${KERNEL_ROOT:-/path/to/sgl-kernel-npu}"

export NPU_DEVICES="${NPU_DEVICES:-0,1,2,3,4,5,6,7}"    # 需修改
export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-32420}"
export BENCH_OUT="${BENCH_OUT:-$PWD/bench_out}"

# 数据集与负载
export DATASET_NAME="${DATASET_NAME:-generated-shared-prefix}"
export GSP_NUM_GROUPS="${GSP_NUM_GROUPS:-1}"
export GSP_PROMPTS_PER_GROUP="${GSP_PROMPTS_PER_GROUP:-5}"
export GSP_SYSTEM_PROMPT_LEN="${GSP_SYSTEM_PROMPT_LEN:-1}"
export GSP_QUESTION_LEN="${GSP_QUESTION_LEN:-32768}"
export GSP_OUTPUT_LEN="${GSP_OUTPUT_LEN:-1}"
export NUM_PROMPTS="${NUM_PROMPTS:-5}"      # random/sharegpt 使用；gsp 由组数决定
export MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"
export WARMUP_REQUESTS="${WARMUP_REQUESTS:-2}"
export SERVER_TAG="${SERVER_TAG:-baseline}"

# Ascend 运行环境；脚本会引用未定义变量，source 期间临时关闭 -u。
set +u
source /usr/local/Ascend/ascend-toolkit/latest/set_env.sh
set -u
export ASCEND_RT_VISIBLE_DEVICES="$NPU_DEVICES"

export PYTHONPATH="$SGLANG_ROOT/python:$KERNEL_ROOT/python/sgl_kernel_npu${PYTHONPATH:+:$PYTHONPATH}"
```

### run_server.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

sglang serve \
  --model-path "$MODEL_PATH" \
  --host 0.0.0.0 --port "$PORT" --trust-remote-code \
  --device npu --tp-size 8 --ep-size 8 --dp-size 8 \
  --enable-dp-attention --enable-dp-lm-head \
  --kv-cache-dtype bfloat16 --page-size 128 \
  --max-running-requests 16 --chunked-prefill-size 32768 \
  --mem-fraction-static 0.8 --context-length 1048576 \
  --moe-a2a-backend deepep --deepep-mode auto \
  --enable-hicache --hicache-ratio 2.5 &
SERVER_PID=$!
trap 'kill -TERM "$SERVER_PID" 2>/dev/null || true' TERM INT
wait "$SERVER_PID"
```

### run_bench.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

mkdir -p "$BENCH_OUT"
OUT="$BENCH_OUT/${SERVER_TAG}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

python3 -m sglang.bench_serving \
  --backend sglang --host "$HOST" --port "$PORT" \
  --model "$MODEL_NAME" \
  --dataset-name "$DATASET_NAME" \
  --gsp-num-groups "$GSP_NUM_GROUPS" \
  --gsp-prompts-per-group "$GSP_PROMPTS_PER_GROUP" \
  --gsp-system-prompt-len "$GSP_SYSTEM_PROMPT_LEN" \
  --gsp-question-len "$GSP_QUESTION_LEN" \
  --gsp-output-len "$GSP_OUTPUT_LEN" \
  --gsp-ordered \
  --max-concurrency "$MAX_CONCURRENCY" \
  --warmup-requests "$WARMUP_REQUESTS" \
  --tokenize-prompt --cache-report --output-details \
  --output-file "$OUT/bench.jsonl" 2>&1 | tee "$OUT/bench.log"

python3 "$HERE/report.py" "$OUT"

echo "输出目录: $OUT"
echo "  原始数据: $OUT/bench.jsonl"
echo "  客户端日志: $OUT/bench.log"
echo "  测试报告: $OUT/report.md"
```

`generated-shared-prefix` 的请求数由 `gsp-num-groups × gsp-prompts-per-group` 决定，不传 `--num-prompts`。换成 `random` 或 `sharegpt` 时，把 `--gsp-*` 换成 `--random-input-len` / `--random-output-len`，并补上 `--num-prompts "$NUM_PROMPTS"`。

### report.py

```python
"""汇总 bench_serving 输出：逐请求 TTFT、均值/分位、吞吐与缓存命中。"""
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
result = json.loads((out / "bench.jsonl").read_text().splitlines()[-1])
ttfts = sorted(t * 1000 for t in result.get("ttfts", []))
cached = result.get("cached_tokens_details") or []

def pct(values, p):
    return values[min(len(values) - 1, int(len(values) * p))] if values else float("nan")

lines = [
    "# 性能测试报告",
    "",
    "| 指标 | 值 |",
    "| --- | --- |",
    f"| 请求数 | {len(result.get('ttfts', []))} |",
    f"| TTFT 均值 | {sum(ttfts) / len(ttfts):.1f} ms |" if ttfts else "| TTFT 均值 | N/A |",
    f"| TTFT p50 / p90 | {pct(ttfts, 0.5):.1f} / {pct(ttfts, 0.9):.1f} ms |",
    f"| 输出吞吐 | {result.get('output_throughput')} tok/s |",
    f"| 请求吞吐 | {result.get('request_throughput')} req/s |",
]

if cached:
    lines += ["", "## 逐请求 TTFT 与缓存命中", "", "| 序号 | TTFT | 命中明细 |", "| --- | --- | --- |"]
    for i, (t, detail) in enumerate(zip(result["ttfts"], cached)):
        lines.append(f"| {i} | {t * 1000:.1f} ms | {detail} |")

(out / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
```

字段名以当前 SGLang 版本的 `bench_serving` 输出为准；缺失字段打印 `N/A`，不要臆造。

## README 必须包含

- 测试场景与关注指标
- 前置依赖：模型、NPU 数量、端口、客户端与服务端是否同机
- 环境变量表
- 服务启动命令（完整、可复制，与 `run_server.sh` 一致）
- 压测命令（完整、可复制）
- 输出物与判定阈值
- 已知限制：缓存状态、其他占用卡、是否代表线上流量

## 判定标准

| 指标 | 允许变化 |
| --- | --- |
| TTFT、TPOT | 相对基线退化不超过 5% |
| 吞吐 | 不低于基线的 95% |
| 缓存命中 | 命中 token 数不减少 |

基线必须是同一模型、同一服务参数、同一数据集参数下的 3 次中位数。比较时同时给出两次的原始 jsonl 路径。

## 结果记录

| 项 | 内容 |
| --- | --- |
| 代码版本 | SGLang 提交号 |
| 模型 | 路径或版本、量化方式 |
| 硬件 | NPU 型号、卡数 |
| 服务参数 | 与基线差异项 |
| 负载 | 数据集类型、长度分布、并发、请求数、warmup |
| 结果 | TTFT p50/p90、TPOT、吞吐、缓存命中 |
| 结论 | 通过或失败、波动范围、原始数据路径 |

## 常见错误

- `warmup-requests 0`：把冷启动算进结论。
- 只跑一次就下结论，不记录波动。
- `max-concurrency` 大于总请求数，大量并发空转。
- 输出长度为 1 却用 TPOT 评价解码性能。
- 对比时同时改了服务端参数和负载参数。
- 客户端加 `--model` 路径与服务端不一致，请求被拒或走错模型。
- 用压测结果评价精度，或反过来。

## 检查清单

- [ ] 模型、卡号、端口、负载参数只在 `env.sh` 定义
- [ ] `run_server.sh` 用 `sglang serve`，参数与 README 一致
- [ ] 客户端只用 `sglang.bench_serving`
- [ ] `warmup-requests` 大于 0，且不超过总请求数
- [ ] `max-concurrency` 不超过总请求数
- [ ] 同场景跑 3 次并取中位数
- [ ] 保留 jsonl 与日志，报告引用原始文件
- [ ] 对比只改一个变量，且记录代码版本与硬件
