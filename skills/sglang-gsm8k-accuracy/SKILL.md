---
name: sglang-gsm8k-accuracy
description: Write and run SGLang GSM8K accuracy regression tests for any model with an explicit accuracy threshold. Use when 用户要跑 GSM8K 精度、新增或评审精度用例，or asks to debug a GSM8K accuracy test. Do not use for 性能压测、单请求冒烟或 PR 格式。
---

# SGLang GSM8K 精度测试规范

约束如何为**任意模型**写 GSM8K 精度回归用例。判定精度是否因某个改动（算子、并行策略、量化、attention backend、cache 策略）退化，而不是验证功能行为。

文中的 DeepSeek-V4-Flash 只作为示例取值，`--attention-backend`、`--quantization`、并行参数都需按目标模型替换。

## 适用与不适用

- 适用：改完代码后确认精度不退化；新增并行/量化/后端参数后的精度对比；CI 精度门禁。
- 不适用：单请求功能验证、KV cache 命中审计、吞吐与性能压测。这些走各自的测试脚本规范。

## 交付物

一个测试文件，随仓库测试体系放置，文件名形如 `test_<模型>_gsm8k_<特性>.py`：

```text
python/sglang/test/ascend/e2e/test_<model>_gsm8k_<feature>.py
```

只需本地复现、不进 CI 时，可放在仓库根目录，用 `python -m unittest` 直接发现。用例必须继承仓库的 `GSM8KAscendMixin`，不能脱离 SGLang 仓库单独运行。

## 硬性要求

### 1. 模型与阈值都从外部给出

- 模型路径用环境变量提供，代码里只保留占位默认值，不写个人目录。
- 精度阈值用环境变量提供，不写死在类属性里，也不允许凭空填一个数。
- 题库规模、few-shot 数同样可覆盖。

### 2. 只写实验组，参数集中

一个文件一个 `TestCase`，直接开启被测特性：

- 服务参数集中在 `BASE_ARGS`，被测特性追加到 `BASE_ARGS` 之后，不复制整份参数表。
- 需要对比精度时，用同一份参数去掉特性开关再跑一次即可，不在文件里固化第二组用例。
- 环境变量集中在 `TEST_ENVS`，与 `os.environ` 合并为 `env`。

### 3. 阈值基于实测，不基于期望

阈值取同一模型、同一参数、同一题目规模下此前的实测精度，略低于实测值。直接把 `accuracy` 当成「预期精度」是常见错误。

### 4. 逻辑不重复

- 启动服务、发请求、解析答案、统计精度由 mixin 负责，测试类里不重复实现。
- 测试文件只做参数声明与特性开关，不写编排代码。

### 5. 规模明确

| 用途 | 题目数 | 说明 |
| --- | --- | --- |
| 快速回归 | `200` | 单次波动可达 1–2 个百分点，只用于排序和发现明显退化 |
| 最终验收 | `1319` | GSM8K 测试集全量，结论以它为准 |

抽样的通过不能替代全量结论。

## 测试类字段

| 字段 | 含义 | 取值方式 |
| --- | --- | --- |
| `model` | 模型权重目录 | `GSM8K_MODEL_PATH` |
| `other_args` | 服务启动参数 | `BASE_ARGS + FEATURE_ARGS` |
| `env` | 服务进程环境变量 | `{**os.environ, **TEST_ENVS}` |
| `accuracy` | 精度阈值，不是实测值 | `GSM8K_ACCURACY` |
| `num_questions` | 题目数 | `GSM8K_NUM_QUESTIONS` |
| `gsm8k_num_shots` | few-shot 数 | `GSM8K_NUM_SHOTS` |
| `timeout_for_server_launch` | 启动超时秒数 | 按机型给，8 卡 NPU 用例常为 `1800` |

## Python 示例

```python
"""GSM8K accuracy regression template for SGLang on NPU.

开启被测特性，断言精度不低于阈值。
"""

import os
import unittest

from sglang.test.ascend.gsm8k_ascend_mixin import GSM8KAscendMixin
from sglang.test.ci.ci_register import register_npu_ci
from sglang.test.test_utils import CustomTestCase

# suite 按机型与卡数选择；不跑 CI 时保留注册即可。
register_npu_ci(suite="full-8-npu-a3")

MODEL = os.environ.get("GSM8K_MODEL_PATH", "/path/to/model")  # 需替换模型路径
NUM_QUESTIONS = int(os.environ.get("GSM8K_NUM_QUESTIONS", "200"))
NUM_SHOTS = int(os.environ.get("GSM8K_NUM_SHOTS", "8"))
ACCURACY = float(os.environ["GSM8K_ACCURACY"])  # 必填：同配置实测精度略低的值

TEST_ENVS = {
    "PYTORCH_NPU_ALLOC_CONF": "expandable_segments:True",
    "STREAMS_PER_DEVICE": "32",
    "HCCL_SOCKET_IFNAME": "lo",
    "GLOO_SOCKET_IFNAME": "lo",
    "HCCL_BUFFSIZE": "1024",
    "DEEPEP_HCCL_BUFFSIZE": "1024",
    "SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK": "128",
}

# 按目标模型替换 backend、量化与并行参数。
BASE_ARGS = [
    "--tp-size", "8",
    "--trust-remote-code",
    "--device", "npu",
    "--attention-backend", "<按模型填写>",
    "--quantization", "<按权重填写>",
    "--kv-cache-dtype", "bfloat16",
    "--page-size", "128",
    "--mem-fraction-static", "0.8",
    "--max-running-requests", "8",
    "--random-seed", "0",
    "--disable-radix-cache",
]

# 被测特性：单独成表，便于关掉后重跑对照。
FEATURE_ARGS = ["--enable-cp-decode-attn-tp"]


class TestGSM8KFeature(GSM8KAscendMixin, CustomTestCase):
    """开启被测特性，断言 GSM8K 精度不低于阈值。"""

    model = MODEL
    other_args = BASE_ARGS + FEATURE_ARGS
    env = {**os.environ, **TEST_ENVS}
    accuracy = ACCURACY
    num_questions = NUM_QUESTIONS
    gsm8k_num_shots = NUM_SHOTS
    timeout_for_server_launch = 1800


if __name__ == "__main__":
    unittest.main()
```

## 运行方式

```bash
cd /path/to/sglang
export PYTHONPATH="$PWD/python${PYTHONPATH:+:$PYTHONPATH}"
export GSM8K_MODEL_PATH=/path/to/model
export GSM8K_ACCURACY=0.93   # 同配置历史实测值略低
python -m unittest -v test_<model>_gsm8k_<feature>
```

需要对照时，临时去掉 `FEATURE_ARGS` 再跑一次同名用例，记录两次实测精度即可，不新增基线用例。

## 判定标准

1. mixin 断言实测精度不低于 `accuracy`，unittest 退出码为 0。
2. 与改动前同配置的实测精度比较：抽样 200 题允许下降 1–2 个百分点，全量 1319 题允许 0.5 个百分点。
3. 任一条不满足即判失败，并保留服务日志与失败题目。

精度提升同样要核对：题目数、few-shot、服务参数未变，否则先排查配置差异。

## 结果记录

| 项 | 内容 |
| --- | --- |
| 代码版本 | SGLang 提交号，必要时附 kernel 提交号 |
| 模型 | 路径或版本，量化方式 |
| 硬件 | NPU 型号、卡数、并行配置 |
| 命令 | 实际执行的 unittest 命令与关键环境变量 |
| 实测精度 | 本次实测值与所用阈值 |
| 对照 | 改动前同配置实测值及差值（有对照时填） |
| 结论 | 通过或失败、失败原因、日志路径 |

未运行的用例必须标注「未运行」及原因，不得写成通过。

## 常见错误

- 把 `accuracy = 0.93` 当成实测精度或期望精度，而不是阈值。
- 直接套用 DSV4 的 `--attention-backend dsv4`、`--quantization modelslim` 到其他模型。
- 为了一次对照就复制整个 `other_args`，两份参数逐渐漂移。
- 模型路径、阈值硬编码在文件里，换机器就失效。
- 用 200 题抽样结果下全量结论。
- 未执行就写「测试通过」。

## 检查清单

- [ ] 模型路径、阈值、题目数、few-shot 均可由环境变量覆盖
- [ ] 服务参数集中在 `BASE_ARGS`，被测特性单独成 `FEATURE_ARGS`
- [ ] 阈值来自同配置实测精度，不高于实测值
- [ ] 启动、评测、统计全部复用 mixin，未重复实现
- [ ] `register_npu_ci` 的 suite 与目标机型匹配
- [ ] 命令可复制执行
- [ ] 记录代码版本、模型、硬件、命令、实测精度与结论
