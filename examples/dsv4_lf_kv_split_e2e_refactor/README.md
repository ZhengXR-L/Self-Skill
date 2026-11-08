# DeepSeek-V4-Flash HiCache AIV 双向搬运验证

## 测试目的

验证 NPU DSV4 的 `layer_first` HiCache 布局（解析为 `layer_first_kv_split`）在 A 阶段落盘、R 阶段回迁时，对指定 DP rank 的七个 KV/state 池的每个物理层都真正调用了 AIV 算子，且回放答案与冷启动答案、真值一致。

## 测试原理

- `gsm8k_aiv.py plan` 从 GSM8K train/test 中各取数据，用训练集 few-shot 构造至少 8192 token 的提示，固定取测试集第 5 题起 N 题；A 与 R 复用完全相同的 input IDs。
- 每题串行执行 `flush_cache → A → B → R`：A 为冷启动生成，`write_through` 触发 D2H；B 用不同前缀、65536 token 的请求驱逐 L1；R 重放 A，要求 L1 命中 0、L2 命中至少 2048 token，触发 H2D。
- 请求固定路由到 `DP_RANK`（默认 0），服务独占，避免其他请求污染阶段审计。
- `aiv_audit_hook.py` 通过 `sitecustomize` 注入 worker，包装当前分支的 `DeepSeekV4PagedHostPool` 与 `DeepSeekV4StateHostPool`。每次真正调用 `transfer_kv_all_layer_kv_split` 或 `transfer_kv_per_layer_kv_split` 时要求 `layout=layer_first_kv_split` 且 `impl="aiv"`，算子返回后在当前 NPU stream 记录 Event，Event 完成才计入 `aiv_complete`。
- 逐题要求所选 DP rank 的 SWA、C4 KV、C4 Indexer K、Indexer scale、C4 state、Indexer state、C128 七个池在各物理层的 A 阶段 D2H 与 R 阶段 H2D 均完成；缺池、缺层、异常或超时判失败。Event 证明算子与所在 stream 完成，不等价于字节级校验。

## 前置依赖

- Linux NPU 容器，已安装 CANN 与 ATB；`npu-smi info` 确认所用物理卡空闲。
- SGLang 源码需将 NPU DSV4 的 `layer_first` 解析为 `layer_first_kv_split` 并在双向搬运中调用 AIV 算子；`sgl-kernel-npu` 需提供对应的 KV split 算子。
- 模型权重默认使用 `/mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp`，权重分片齐全，加载方式为 `modelslim`。
- GSM8K 训练集与测试集 JSONL，每行含 `question` 与 `answer`。
- 八张空闲 NPU、端口 `32420` 未被占用、输出目录为全新目录。

## 环境变量

| 变量 | 示例值 | 含义 | 必填 |
| --- | --- | --- | --- |
| `MODEL_PATH` | `/mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp` | 模型权重目录 | 是 |
| `TRAIN_PATH` | `/path/to/gsm8k_train.jsonl` | few-shot 数据 | 是 |
| `TEST_PATH` | `/path/to/gsm8k_test.jsonl` | 评测数据 | 是 |
| `SGLANG_ROOT` | `/path/to/sglang` | SGLang 源码根目录 | 是 |
| `KERNEL_ROOT` | `/path/to/sgl-kernel-npu` | sgl-kernel-npu 根目录 | 是 |
| `NPU_DEVICES` | `0,1,2,3,4,5,6,7` | 物理卡 ID | 是 |
| `ASCEND_RT_VISIBLE_DEVICES` | 由 `NPU_DEVICES` 派生 | 进程实际可见卡 | 否 |
| `PORT` | `32420` | 服务端口 | 否 |
| `DP_RANK` | `0` | 被审计的 DP rank | 否 |
| `NUM_QUESTIONS` | `3` | 题目数，完整回归改 `100` | 否 |
| `TEST_OFFSET` | `5` | 测试集起始下标 | 否 |
| `MIN_PROMPT_TOKENS` | `8192` | 提示最小 token 数 | 否 |
| `MAX_SHOTS` | `128` | few-shot 示例上限 | 否 |
| `MAX_NEW_TOKENS` | `512` | 每题生成上限 | 否 |
| `EVICTION_TOKENS` | `65536` | B 阶段驱逐 L1 的请求长度 | 否 |
| `STARTUP_TIMEOUT` | `3600` | 服务就绪等待秒数 | 否 |
| `AUDIT_TIMEOUT` | `30` | 单次审计等待秒数 | 否 |
| `QUANTIZATION` | `modelslim` | 量化方式，非量化权重留空 | 否 |

`env.sh` 另集中定义以下 NPU 调优变量，默认值来自既有 DSV4 测试，通常无需修改：

```text
SGLANG_HICACHE_HOST_MEM_BACKEND  SGLANG_DSV4_FP4_EXPERTS  PYTORCH_NPU_ALLOC_CONF
STREAMS_PER_DEVICE  SGLANG_SET_CPU_AFFINITY  HCCL_BUFFSIZE  HCCL_SOCKET_IFNAME
GLOO_SOCKET_IFNAME  HCCL_INTRA_DMA_ENABLE  DEEPEP_HCCL_BUFFSIZE
SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK  SGLANG_OPT_*  SGLANG_ENABLE_*
SGLANG_NPU_USE_MULTI_STREAM  SGLANG_ZBAL_LOCAL_MEM_SIZE  SGLANG_ENABLE_WAR_BARRIER
SGLANG_FORCE_COARSE_WAR_BARRIER  ASCEND_TOOLKIT_ROOT  CANN_PYTHON_SITE_PACKAGES
PYTHONPATH
```

## 执行方式

修改 `env.sh` 中的路径与卡号后：

```bash
bash run_test.sh /path/to/output_dir
```

脚本自动完成：构造 plan → 启动服务 → 等待 `/health` → 逐题评测 → 生成 `report.md` → 退出时关闭服务。换机器只改 `env.sh`。运行结束（含失败或 Ctrl-C）会在终端打印输出目录与各日志路径。

## 服务启动命令

`run_server.sh` 内部执行的完整命令（`QUANTIZATION=modelslim`、`PORT=32420`、`MODEL_PATH` 取默认值时）：

```bash
sglang serve \
  --model-path /mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp \
  --host 127.0.0.1 --port 32420 --trust-remote-code \
  --tp-size 8 --ep-size 8 --dp-size 8 --enable-dp-attention --enable-dp-lm-head \
  --device npu --attention-backend dsv4 --quantization modelslim --kv-cache-dtype bfloat16 \
  --page-size 128 --swa-full-tokens-ratio 0.1 --max-total-tokens 66000 \
  --max-running-requests 16 --chunked-prefill-size 32768 --mem-fraction-static 0.8 \
  --moe-a2a-backend deepep --deepep-mode auto --watchdog-timeout 9000 --random-seed 0 \
  --context-length 1048576 --cuda-graph-backend-prefill disabled \
  --cuda-graph-backend-decode disabled \
  --enable-hicache --hicache-mem-layout layer_first \
  --hicache-io-backend kernel_ascend --hicache-write-policy write_through \
  --hicache-ratio 2.5
```

手动执行前必须先 `source env.sh`（其中已 source Ascend 环境）并完成审计 hook（`AUDIT_DIR/boot`）设置，否则 D2H/H2D 审计无法生效。

## 输出物与判定

| 路径 | 内容 |
| --- | --- |
| `plan.json` / `plan.log` | 固化的题目与输入 token |
| `server.log` | 服务启动日志 |
| `audit/launch.json` | SGLang 与 sgl-kernel-npu 提交号、启动信息 |
| `audit/calls-*.jsonl` | AIV 调用审计流水 |
| `audit/boot/` | 注入的 `sitecustomize.py` 与审计 hook |
| `results/summary.json` | 汇总判定 |
| `results/<qid>/` | 每题请求、响应与审计结果 |
| `eval.log` | 评测过程日志 |
| `report.md` / `report.log` | 简要测试报告（结论、版本、配置、逐题结果）及生成日志 |

判定：`summary.json` 中 `passed=true` 表示所选 DP rank 的七池全部层双向 AIV 完成、A/R 答案一致且与真值一致。退出码非 0 即失败，进程退出码反映最终结论。`report.md` 是该结论的可读汇总，不重新计算判定，评测失败时同样生成。

## 已知限制

- 只覆盖 `DP_RANK` 指定的单个 DP rank，不逐题验证其余 7 个 rank。
- 不评价并发吞吐与性能。
- 审计基于 NPU stream Event，不是 KV/state 字节级校验。
- 需要专用空闲服务，不能与其他请求共用同一实例。
