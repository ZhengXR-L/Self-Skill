---
name: sglang-gsm8k-accuracy
description: Prepare and run the provided SGLang NPU GSM8K accuracy regression example for DeepSeek-V4-Flash with context parallelism.
---

# SGLang NPU GSM8K 精度回归测试

使用下方 Python 示例检查 DeepSeek-V4-Flash 在 NPU 上开启 `--enable-cp-decode-attn-tp` 后的 GSM8K 精度。此示例依赖 SGLang 仓库中的 Ascend 测试工具，不能作为独立 Python 脚本脱离仓库运行。

## 环境准备

- 使用包含示例所引用模块和模型常量的 SGLang 代码版本，并配置好 Ascend NPU 运行环境。
- 准备 8 张可用 NPU；示例配置为 TP=8、Attention CP=8、DP=1、EP=8。
- 确认 `DEEPSEEK_V4_FLASH_0731_W8A8_MODEL_PATH` 指向可访问的模型权重。
- 确认 GSM8K 数据集可由当前测试工具访问。
- 下方命令使用 Linux Bash；将源码路径替换为实际路径。

## 使用步骤

1. 将下方 Python 代码保存为 SGLang 仓库根目录下的 `test_npu_gsm8k_accuracy.py`。
2. 在已配置好的 NPU 环境中执行：

```bash
cd /path/to/sglang
export PYTHONPATH="$PWD/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONUNBUFFERED=1
python -m unittest -v test_npu_gsm8k_accuracy
```

测试类通过 `GSM8KAscendMixin` 和仓库测试工具管理服务与评测；无需按单请求示例另行启动服务。具体启动、评测和判定逻辑以当前版本的 mixin 实现为准。

## 关键配置

| 配置 | 示例值 | 含义 |
| --- | --- | --- |
| `accuracy` | `0.93` | 传给测试工具的精度阈值，并非已测得的结果。 |
| `num_questions` | `200` | 评测题目数。 |
| `gsm8k_num_shots` | `8` | Few-shot 示例数。 |
| `timeout_for_server_launch` | `1800` | 服务启动超时时间，单位为秒。 |
| `--attention-backend` | `dsv4` | 此模型示例使用的注意力后端。 |
| `--quantization` | `modelslim` | 此模型示例使用的量化配置。 |

保留下面的环境变量、服务参数和 CI 注册配置，以复现原始用例。迁移到其他模型、硬件或代码版本时，应先核对参数支持情况及 CI suite 归属，不要直接套用本示例。

## Python 测试示例

```python
"""GSM8K accuracy regression for NPU.
"""

import os
import unittest

from sglang.test.ascend.e2e.test_npu_performance_utils import (
    DEEPSEEK_V4_FLASH_0731_W8A8_MODEL_PATH,
)

from sglang.test.ascend.gsm8k_ascend_mixin import GSM8KAscendMixin
from sglang.test.ci.ci_register import register_npu_ci
from sglang.test.test_utils import CustomTestCase

register_npu_ci(suite="full-8-npu-a3")

TEST_ENVS = {
    "PYTORCH_NPU_ALLOC_CONF": "expandable_segments:True",
    "STREAMS_PER_DEVICE": "32",
    "HCCL_SOCKET_IFNAME": "lo",
    "GLOO_SOCKET_IFNAME": "lo",
    "HCCL_BUFFSIZE": "1024",
    "DEEPEP_HCCL_BUFFSIZE": "1024",
    "SGLANG_ZBAL_LOCAL_MEM_SIZE": "0",
    "SGLANG_ENABLE_TP_MEMORY_INBALANCE_CHECK": "1",
    "SGLANG_NPU_USE_MULTI_STREAM": "0",
    "SGLANG_ENABLE_OVERLAP_PLAN_STREAM": "0",
    "SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK": "128",
    "SGLANG_OPT_FP8_WO_A_GEMM": "0",
    "SGLANG_DSV4_FP4_EXPERTS": "False",
    "SGLANG_OPT_FUSE_WQA_WKV": "0",
    "SGLANG_OPT_BF16_FP32_GEMM_ALGO": "torch",
    "SGLANG_OPT_USE_FUSED_HASH_TOPK": "False",
    "SGLANG_OPT_USE_TILELANG_MHC_PRE": "False",
    "SGLANG_OPT_DEEPGEMM_HC_PRENORM": "False",
    "SGLANG_OPT_USE_TILELANG_MHC_POST": "False",
}

SERVER_ARGS = [
    "--tp-size",
    "8",
    "--attn-cp-size",
    "8",
    "--dp-size",
    "1",
    "--ep-size",
    "8",
    "--enable-prefill-cp",
    "--cp-strategy",
    "interleave",
    "--enable-cp-decode-attn-tp",
    "--trust-remote-code",
    "--device",
    "npu",
    "--attention-backend",
    "dsv4",
    "--quantization",
    "modelslim",
    "--kv-cache-dtype",
    "bfloat16",
    "--page-size",
    "128",
    "--mem-fraction-static",
    "0.8",
    "--chunked-prefill-size",
    "4096",
    "--prefill-max-requests",
    "8",
    "--max-running-requests",
    "8",
    "--moe-a2a-backend",
    "deepep",
    "--deepep-mode",
    "auto",
    "--watchdog-timeout",
    "600",
    "--random-seed",
    "0",
    "--disable-radix-cache",
    "--cuda-graph-backend-prefill",
    "disabled",
    "--cuda-graph-backend-decode",
    "full",
    "--cuda-graph-bs-decode",
    "1",
    "2",
    "4",
    "8",
]


class TestNPUCpDecodeAttnTP(GSM8KAscendMixin, CustomTestCase):
    """Testcase: Verify that --enable-cp-decode-attn-tp keeps GSM8K accuracy on NPU
    for DeepSeek-V4-Flash with context parallelism (--attn-cp-size 8).

    [Test Category] Context Parallel
    [Test Target] --enable-cp-decode-attn-tp
    """

    model = DEEPSEEK_V4_FLASH_0731_W8A8_MODEL_PATH
    timeout_for_server_launch = 1800
    other_args = SERVER_ARGS
    env = {**os.environ, **TEST_ENVS}
    accuracy = 0.93
    num_questions = 200
    gsm8k_num_shots = 8


if __name__ == "__main__":
    unittest.main()

```

## 结果记录

记录代码版本、模型路径或版本、NPU 型号及数量、执行命令、实际精度、测试通过情况和失败日志。比较修改前后结果时保持题目数、few-shot 数和运行配置一致。

本文仅提供测试用例，不代表已执行或通过测试。未运行时应明确标注“未运行”及原因。
