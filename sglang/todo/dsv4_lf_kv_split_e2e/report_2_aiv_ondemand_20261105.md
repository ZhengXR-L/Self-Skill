# DeepSeek-V4-Flash DSV4 AIV D2H/H2D 验证

SGLang 提交：`50038e53510a437493a4537ea00aca582ea16e47`；sgl-kernel-npu 提交：`2258170f420befbdd2c5f18726cecd7a8e251b53`。
SGLang 工作区状态：` M python/sglang/srt/hardware_backend/npu/dsv4/dsv4_memory_pool.py
 M python/sglang/srt/mem_cache/memory_pool_host.py
 M python/sglang/srt/mem_cache/pool_host/mla.py
`。

## 服务命令

```bash
/usr/local/python3.12.13/bin/python3 -m sglang.launch_server --model-path /mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp --host 127.0.0.1 --port 35000 --trust-remote-code --tp-size 8 --ep-size 8 --dp-size 8 --enable-dp-attention --enable-dp-lm-head --device npu --attention-backend dsv4 --quantization modelslim --kv-cache-dtype bfloat16 --page-size 128 --swa-full-tokens-ratio 0.1 --max-total-tokens 66000 --max-running-requests 16 --chunked-prefill-size 32768 --mem-fraction-static 0.8 --moe-a2a-backend deepep --deepep-mode auto --watchdog-timeout 9000 --random-seed 0 --context-length 1048576 --cuda-graph-backend-prefill disabled --cuda-graph-backend-decode disabled --enable-hicache --hicache-mem-layout layer_first --hicache-io-backend kernel_ascend --hicache-write-policy write_through --hicache-ratio 2.5
```

审计只统计显式 impl=aiv、算子返回且 NPU stream event 完成的记录。

## 2 题结果

```json
{
  "planned_questions": 2,
  "covered_questions": 2,
  "path_coverage": 1.0,
  "all_questions_complete": true,
  "baseline_accuracy": 1.0,
  "replay_accuracy": 1.0,
  "baseline_correct_completed": 2,
  "replay_correct_completed": 2,
  "answer_match_count": 2,
  "token_match_count": 2,
  "absolute_accuracy_gate": null,
  "error": null,
  "passed": true,
  "protocol": "long-few-shot; relative answer preservation; not original 5-shot",
  "cold_definition": "flush establishes KV-cache cold, not process/state-memory cold"
}
```

few-shot 示例数：51；输入长度：8274～8289 token。
解析布局：`layer_first_kv_split`；I/O：`kernel_ascend`。

- test-5: A=64, R=64, 真值=64, L1=0, L2=8192, 答案一致=True, 双向路径=True
- test-6: A=2.6E+2, R=2.6E+2, 真值=2.6E+2, L1=0, L2=8192, 答案一致=True, 双向路径=True

首题各池审计覆盖：

- swa: D2H 43/43 层，H2D 43/43 层，完成调用 86/43
- deepseek_v4_c4: D2H 21/21 层，H2D 21/21 层，完成调用 42/21
- deepseek_v4_c4_indexer: D2H 21/21 层，H2D 21/21 层，完成调用 42/21
- deepseek_v4_c4_indexer_scale: D2H 21/21 层，H2D 21/21 层，完成调用 42/21
- deepseek_v4_c4_state: D2H 21/21 层，H2D 21/21 层，完成调用 42/21
- deepseek_v4_c4_indexer_state: D2H 21/21 层，H2D 21/21 层，完成调用 42/21
- deepseek_v4_c128: D2H 20/20 层，H2D 20/20 层，完成调用 40/20

## 边界

本次模型为 W8A8 MTP（modelslim）：`/mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp`。
NPU event 证明算子所在 stream 完成；未对 KV/state 字节逐一比对。
A/R 答案与真值用于发现可见的回放错误；测试不评价并发或 TTFT。

证据目录：`/home/l00889655/sglang/dsv4_accuracy_20261105/lf_2_back8_aiv_ondemand_fix_35000`。
