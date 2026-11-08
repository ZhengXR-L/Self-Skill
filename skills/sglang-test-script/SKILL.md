---
name: sglang-test-script
description: Author or review SGLang feature test script bundles with a README, one centralized env file, and a full server launch command. Use when 用户要为 SGLang 特性写、重构或评审测试脚本，or asks to write a reproduction script. Do not use for 单请求冒烟、GSM8K 精度、性能压测或 PR 格式。
---

# SGLang 测试脚本规范

约束为 SGLang 某个特性（参数、算子、缓存、调度等）生成的可复现测试脚本集。目标是让另一个人换一台机器、只改一个文件就能跑通并判断结果。

说明文字用中文，命令与参数保持英文原文。

## 交付物结构

```text
<feature_test>/
├── README.md        # 必需：使用说明
├── env.sh           # 必需：唯一的配置入口
├── run_server.sh    # 必需：完整服务启动命令
├── run_test.sh      # 必需：评测主入口，自己起停服务
├── report.py        # 必需：读取输出目录，生成 report.md
└── <aux>.py         # 可选：被测逻辑、数据构造、结果采集
```

`run_test.sh` 用一个位置参数接收输出目录，其余全部从 `env.sh` 读取：

```bash
bash run_test.sh <output_dir>
```

## 硬性要求

### 1. README.md 必须说明使用方法

必须包含以下小节，缺一不可：

| 小节 | 内容 |
| --- | --- |
| 测试目的 | 验证哪个特性或参数，预期看到什么现象 |
| 测试原理 | 为什么这样构造请求与判定，关键路径是什么 |
| 前置依赖 | 模型、数据集、代码版本、硬件型号与数量、镜像或 CANN 版本 |
| 环境变量 | 表格：变量名、示例值、含义、是否必填 |
| 执行命令 | 可直接复制运行的一条命令，含输出目录 |
| 服务启动命令 | 完整参数、可直接复制的 SGLang 启动命令 |
| 输出物与判定 | 生成哪些文件，怎么算通过、怎么算失败 |
| 已知限制 | 不覆盖的 rank、不支持并发、不做性能评价等 |

「服务启动命令」必须把参数写全，不能写「见 `run_server.sh`」。脚本里的启动参数与 README 必须一致。

### 2. env.sh 是唯一的配置来源

所有可变项集中在 `env.sh`，其他脚本只 `source`，禁止再次定义或写默认值：

- 路径：模型、训练/测试数据集、SGLang 源码、sgl-kernel、输出根目录
- 硬件：`NPU_DEVICES`（物理卡 ID 列表）
- 运行：`PORT`、`DP_RANK`、题数、超时、驱逐 token 数
- 全部 `SGLANG_*`、`HCCL_*`、`PYTORCH_NPU_*` 环境变量
- Ascend 环境：所需 `set_env.sh` 也在 `env.sh` 中 source，`run_server.sh` 不再重复 source
- 派生项：`PYTHONPATH`、`ASCEND_RT_VISIBLE_DEVICES` 在 `env.sh` 内由上面的值算出来

每项用 `export VAR="${VAR:-default}"`，允许调用方覆盖。默认值里凡是机器相关的绝对路径，必须加 `# 需修改` 注释。README 的环境变量表与 `env.sh` 一一对应。

### 3. 脚本内容精简

- 保留：`set -euo pipefail`、服务健康等待、结果判定、退出码。
- 删除：模型分片逐个存在性校验、权重文件全量 sha256、参数形状断言、与测试目标无关的日志与封装。
- 不引入抽象层、配置解析器、通用工具模块。三个脚本能说清的事不要拆成五层。
- 辅助 Python 只做数据构造、请求发送、结果统计；不重复实现运维检查。

### 4. 跨环境可执行

- NPU 卡号必须可指定，通过 `NPU_DEVICES` 注入 `ASCEND_RT_VISIBLE_DEVICES`；卡数从列表长度推导，不写死 `== 8`。
- 不硬编码容器名、主机名、个人目录；这些只作为 `env.sh` 里带 `# 需修改` 的默认值出现。
- 端口、输出目录、题数都可覆盖，端口冲突时只改 `env.sh`。
- 脚本用 `HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)` 定位自身，不依赖当前工作目录。
- 不假设 Ascend 环境变量已预先 source；在 `env.sh` 中 source 所需 `set_env.sh`，并设置 `ASCEND_RT_VISIBLE_DEVICES`。
- 服务统一用 `sglang serve` 启动，不写 `python3 -m sglang.launch_server`，也不加 `exec`。
- 一个入口脚本完成起停服务与评测，运行结束在终端打印输出目录与各日志路径。

### 5. 日志与输出

- 每个子步骤的 stdout/stderr 重定向到输出目录下的固定文件，例如 `server.log`、`plan.log`、`eval.log`。
- 入口脚本在退出时（成功、失败、Ctrl-C）打印输出目录与每个日志的完整路径，不要只在成功路径打印。
- 终端只保留进度与最终判定，不刷大段日志；需要细节时按打印的路径查看。
- `README.md` 的「输出物与判定」列出同样的文件路径，与脚本中的文件名保持一致。

### 6. 运行后生成简要报告

评测结束后由 `report.py` 生成 `<输出目录>/report.md`，评测失败也要生成。报告只做汇总，不重新计算判定：

- 结论：通过或失败，以及失败原因
- 被测代码版本：仓库路径与提交号
- 模型、硬件（卡号）、端口、量化等关键配置
- 指标汇总表：题目数、覆盖情况、精度、答案/token 一致数
- 逐题结果表：真值、实际输出、是否一致、是否通过

报告中引用的启动命令写入 README，不在报告里重复整段参数。`run_test.sh` 用 `set +e` 跑评测，记录退出码，生成报告后再以该退出码退出。

## 脚本示例

### env.sh

```bash
#!/usr/bin/env bash
# 唯一配置入口。按实际环境修改标记为「需修改」的默认值。

export MODEL_PATH="${MODEL_PATH:-/path/to/model}"            # 需修改
export TRAIN_PATH="${TRAIN_PATH:-/path/to/train.jsonl}"      # 需修改
export TEST_PATH="${TEST_PATH:-/path/to/test.jsonl}"         # 需修改
export SGLANG_ROOT="${SGLANG_ROOT:-/path/to/sglang}"         # 需修改
export KERNEL_ROOT="${KERNEL_ROOT:-/path/to/sgl-kernel-npu}" # 需修改

export NPU_DEVICES="${NPU_DEVICES:-0,1,2,3,4,5,6,7}"         # 需修改：空闲物理卡
export PORT="${PORT:-30000}"
export DP_RANK="${DP_RANK:-0}"
export NUM_QUESTIONS="${NUM_QUESTIONS:-3}"
export STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-1800}"
export EVICTION_TOKENS="${EVICTION_TOKENS:-65536}"

# Ascend 运行环境；这些脚本会引用未定义变量，source 期间临时关闭 -u。
set +u
source /usr/local/Ascend/ascend-toolkit/latest/set_env.sh
set -u
export ASCEND_RT_VISIBLE_DEVICES="$NPU_DEVICES"

export SGLANG_HICACHE_HOST_MEM_BACKEND="${SGLANG_HICACHE_HOST_MEM_BACKEND:-memfabric}"
export PYTORCH_NPU_ALLOC_CONF="${PYTORCH_NPU_ALLOC_CONF:-expandable_segments:True}"
export HCCL_BUFFSIZE="${HCCL_BUFFSIZE:-2048}"
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
  --host 127.0.0.1 --port "$PORT" --trust-remote-code \
  --device npu --attention-backend dsv4 \
  --tp-size 8 --dp-size 1 --enable-hicache &
SERVER_PID=$!
trap 'kill -TERM "$SERVER_PID" 2>/dev/null || true' TERM INT
wait "$SERVER_PID"
```

不要加 `exec`；后台运行并用 trap 转发 TERM，由 `run_test.sh` 管理起停。参数列表必须与 README 中的启动命令逐字一致。

### run_test.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/env.sh"

OUT=${1:?usage: bash run_test.sh <output_dir>}
mkdir -p "$OUT"

trap 'kill -TERM "${SERVER_PID:-}" 2>/dev/null || true
echo "输出目录: $OUT"
echo "  服务日志: $OUT/server.log"
echo "  评测日志: $OUT/eval.log"
echo "  测试报告: $OUT/report.md"' EXIT

bash "$HERE/run_server.sh" > "$OUT/server.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 "$STARTUP_TIMEOUT"); do
  if curl -sf "http://127.0.0.1:$PORT/health" > /dev/null; then break; fi
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/health" > /dev/null || { echo "server not ready"; exit 1; }

set +e
python3 -u "$HERE/run_case.py" \
  --base-url "http://127.0.0.1:$PORT" \
  --num-questions "$NUM_QUESTIONS" \
  --output "$OUT" 2>&1 | tee "$OUT/eval.log"
EVAL_RC=${PIPESTATUS[0]}
set -e

python3 -u "$HERE/report.py" "$OUT" 2>&1 | tee "$OUT/report.log"
exit "$EVAL_RC"
```

一个入口脚本负责起停服务、执行评测并生成报告；日志路径写在 EXIT trap 里，失败或中断时同样会打印。

## README 骨架

````markdown
# <特性名> 测试

## 测试目的

## 测试原理

## 前置依赖

## 环境变量

| 变量 | 示例值 | 含义 | 必填 |
| --- | --- | --- | --- |

## 执行方式

```bash
bash run_test.sh /path/to/output
```

## 服务启动命令

```bash
<与 run_server.sh 一致的完整命令>
```

## 输出物与判定

## 已知限制
````

## 反例

- 默认路径、端口、卡号散落在 `run_server.sh`、`run_test.py`、README 三处，改一处就不同步。
- 评测入口里校验模型每个分片存在、对全部脚本和权重算 sha256：与测试目标无关，拉长启动且无法复现环境差异。
- `assert len(ids) == 8`：卡数写死，换机器即失败。
- README 只写「完整参数见脚本」：换环境的人无法核对参数。
- 把容器名、个人 home 路径写进执行命令。

## 交付前检查清单

- [ ] README 包含全部八个小节，服务启动命令参数完整且与脚本一致
- [ ] 所有路径、卡号、端口、SGLANG 环境变量、Ascend `set_env.sh` 只在 `env.sh` 处理
- [ ] 除 `env.sh` 外没有任何硬编码绝对路径或卡号
- [ ] 卡数由 `NPU_DEVICES` 推导，可为任意张数
- [ ] 无模型分片、文件哈希、参数形状等无关校验
- [ ] 所有脚本 `set -euo pipefail`，评测入口有健康等待与退出码
- [ ] `bash run_test.sh <output_dir>` 可一条命令完成起服务、测试、生成报告、停服务
- [ ] 评测结束生成 `report.md`，失败时也生成，终端打印其路径
- [ ] 结果记录代码版本、模型、硬件、命令、判定，未运行不写通过
