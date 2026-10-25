---
name: sglang-single-request
description: Start the provided SGLang server example on Ascend NPU and send a single inference request to verify the service.
---

# SGLang NPU 单请求示例

在 Ascend NPU 上启动使用 `ascend` 注意力后端的 SGLang 服务，并发送一个请求检查基本推理是否正常。

## 环境准备

- 已配置可用的 Ascend NPU 环境和支持该后端的 SGLang 版本。
- 已准备模型权重，并确认服务端口 `7777` 可用。
- 以下命令使用 Linux Bash，在运行 SGLang 的 NPU 主机上执行。
- 将示例中的源码路径和模型路径替换为实际路径。

## 启动服务端

在第一个终端执行：

```bash
export PYTHONPATH="/home/l00889655/sglang/sglang/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONUNBUFFERED=1

sglang serve \
  --model-path /home/weights/Qwen3-0.6B \
  --device npu \
  --mem-fraction-static 0.75 \
  --attention-backend ascend \
  --host 127.0.0.1 \
  --port 7777
```

| 参数 | 示例值 | 说明 |
| --- | --- | --- |
| `--model-path` | `/home/weights/Qwen3-0.6B` | 本地模型权重目录。 |
| `--device` | `npu` | 使用 NPU 设备。 |
| `--mem-fraction-static` | `0.75` | 静态显存分配比例。 |
| `--attention-backend` | `ascend` | 使用 Ascend 注意力后端。 |
| `--host` | `127.0.0.1` | 仅监听本机回环地址。 |
| `--port` | `7777` | 服务监听端口。 |

## 发送单个请求

等待服务完成模型加载并就绪后，在同一主机的第二个终端执行：

```bash
curl --fail-with-body --silent --show-error \
  http://127.0.0.1:7777/generate \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "The capital of France is",
    "sampling_params": {
      "temperature": 0,
      "max_new_tokens": 32
    }
  }'
```

检查 HTTP 请求是否成功，以及响应 JSON 中是否包含生成文本。实际文本可能随模型和运行版本变化，无需逐字匹配固定答案。

## 结果与排查

- 连接失败：查看服务日志，确认模型加载完成，并核对主机地址和端口。
- 模型加载或后端初始化失败：核对模型路径、NPU 环境，以及当前 SGLang 版本对相关参数的支持。
- 请求报错：保留响应正文和服务日志，检查请求格式及错误原因。

记录代码版本、模型、硬件、启动命令和响应结果。此示例用于基本推理检查；GSM8K 精度回归请参见 [GSM8K 测试技能](../gsm8k_accuracy/SKILL.md)。

完成后，在服务端终端按 `Ctrl+C` 停止服务。
