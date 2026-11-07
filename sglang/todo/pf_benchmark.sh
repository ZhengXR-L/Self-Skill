# python3 -m sglang.bench_serving \
#   --backend sglang \
#   --host 127.0.0.1 --port 32420 \
#   --model /mnt/share/DeepSeek-V4-Flash-0731-w8a8 \
#   --dataset-name generated-shared-prefix \
#   --gsp-num-groups 1 --gsp-prompts-per-group 5 \
#   --gsp-system-prompt-len 1 --gsp-question-len 32000 --gsp-output-len 1 \

export PYTHONPATH=/home/l00889655/sglang/sglang/python:$PYTHONPATH
# export PYTHONPATH=/home/l00889655/sglang/sglang_work2/sglang/python:$PYTHONPATH
#   --extra-request-body '{"routed_dp_rank":0}' \
python3 -m sglang.bench_serving \
  --backend sglang \
  --host 127.0.0.1 --port 32420 \
  --model /mnt/paas/weights/DeepSeek-V4-Flash-0731-w8a8 \
  --dataset-name generated-shared-prefix \
  --gsp-num-groups 1 --gsp-prompts-per-group 5 \
  --gsp-system-prompt-len 1 --gsp-question-len 32768 --gsp-output-len 1 \
  --gsp-ordered --warmup-requests 0 --max-concurrency 1 \
  --tokenize-prompt \
  --cache-report --output-details \
  --output-file /home/l00889655/run_file/dsv4/bench_run0.jsonl

# python3 - <<'PY'
# import json

# for path in (
#     "/home/l00889655/run_file/dsv4/bench_run1.jsonl",
#     "/home/l00889655/run_file/dsv4/bench_run2.jsonl",
# ):
#     result = json.loads(open(path).readlines()[-1])
#     print(path)
#     for i, (ttft, tiers) in enumerate(
#         zip(result["ttfts"], result["cached_tokens_details"])
#     ):
#         print(i, f"{ttft * 1000:.1f} ms", tiers)
# PY