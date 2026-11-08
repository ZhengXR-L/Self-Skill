"""生成简要测试报告：结论、代码版本、配置与逐题结果。"""
import json
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
read = lambda path: json.loads(Path(path).read_text(encoding="utf-8"))

launch = read(root / "audit/launch.json")
plan = read(root / "plan.json")
results = root / "results"
summary = read(results / "summary.json") if (results / "summary.json").exists() else {}
rows = [json.loads(line) for line in (results / "results.jsonl").read_text().splitlines()] \
    if (results / "results.jsonl").exists() else []

verdict = "通过" if summary.get("passed") else "失败"
fmt = lambda value: "N/A" if value is None else value
lines = [
    "# DeepSeek-V4-Flash DSV4 HiCache AIV 双向搬运测试报告",
    "",
    f"**结论：{verdict}**",
    "",
    "## 配置",
    "",
    f"- SGLang 提交：`{launch.get('git_commit')}`（`{launch.get('sglang_root')}`）",
    f"- sgl-kernel-npu 提交：`{launch.get('kernel_commit')}`（`{launch.get('kernel_root')}`）",
    f"- 模型：`{launch.get('model_path')}`",
    f"- 物理卡：`{launch.get('npu_devices')}`，端口：`{launch.get('port')}`，量化：`{launch.get('quantization')}`",
    f"- 题目数：{len(plan.get('questions', []))}，few-shot 上限：{plan.get('num_shots')}",
    "",
    "完整服务启动命令见 `README.md` 的「服务启动命令」。",
    "",
    "## 结果",
    "",
    "| 指标 | 值 |",
    "| --- | --- |",
    f"| 计划题目 | {summary.get('planned_questions', 0)} |",
    f"| 双向路径覆盖 | {summary.get('covered_questions', 0)}（{summary.get('path_coverage', 0):.0%}） |",
    f"| 冷启动精度 | {fmt(summary.get('baseline_accuracy'))} |",
    f"| 重放精度 | {fmt(summary.get('replay_accuracy'))} |",
    f"| 答案一致 | {summary.get('answer_match_count', 0)} |",
    f"| token 一致 | {summary.get('token_match_count', 0)} |",
]

if summary.get("error"):
    lines += ["", f"**错误：** `{summary['error']}`"]

if rows:
    lines += ["", "## 逐题结果", "",
              "| 题号 | 真值 | 冷启动 | 重放 | 答案一致 | token 一致 | 路径覆盖 | 判定 |",
              "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for row in rows:
        lines.append(
            f"| {row['qid']} | {row['ground_truth']} | {row['baseline_answer']} | "
            f"{row['replay_answer']} | {row['answer_match']} | {row['token_match']} | "
            f"{row['path_covered']} | {'通过' if row['passed'] else '失败'} |")

lines += ["", "审计口径：只统计 `layout=layer_first_kv_split` 且 `impl=aiv`、算子返回且 NPU stream Event 完成的调用；不代表 KV/state 字节级校验。", ""]
(root / "report.md").write_text("\n".join(lines), encoding="utf-8")
print(f"report: {root / 'report.md'}")
