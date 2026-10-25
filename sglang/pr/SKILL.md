---
name: pr
description: Draft and review SGLang pull request titles and descriptions using the required title format, test evidence, and contribution checklist.
---

# SGLang PR 编写规范

用于编写或检查 SGLang Pull Request（PR）的标题和描述。说明使用中文，PR 标题及正文模板使用英文。

## 使用流程

1. 根据实际变更确定类型、模块或模型名称，以及是否需要硬件标签。
2. 按下方规则生成或检查 PR 标题。
3. 根据实际变更填写描述，说明动机、修改内容和验证结果。
4. 涉及模型输出时提供准确性测试；涉及推理速度时提供性能测试和分析结果。
5. 逐项核对检查清单，仅勾选已完成的项目。未运行的测试应明确说明原因，不得编造结果；不适用的测试注明 `N/A` 并说明原因。

## PR 标题

### 格式

```text
[Type] scope: title
[Type] [Hardware] scope: title
```

| 字段 | 必填 | 规则 |
| --- | --- | --- |
| `Type` | 是 | 仅允许 `Feat`、`Fix`、`Refactor`、`Perf`、`Doc`、`Test`、`CI`、`Chore`，大小写必须一致。 |
| `Hardware` | 否 | 单个不含空格的硬件标签。默认使用大写，例如 `AMD`、`NVIDIA`、`NPU`、`MI300X`；例外拼写为 `Intel`、`Apple`、`Huawei`、`Ascend`。 |
| `scope` | 是 | 模块或模型名称，无固定列表或大小写限制；仅允许字母、数字、`.`、`_`、`/`、`-`。 |
| `title` | 是 | 非空的变更说明，无大小写限制。 |

标题不得有首尾空白，冒号后必须有且仅有一个空格。字段和标签之间的空格按上述格式填写。标题格式不符合要求会导致 CI 失败。

GitHub 自动生成的回滚标题可免于上述格式要求：

```text
Revert "original title"
```

### 示例

```text
[Fix] attention: Fix KV cache indexing
[Perf] [AMD] flash-attn: Optimize decode performance
```

## PR 描述模板

复制下方模板并填写。HTML 注释用于提示填写要求，在 GitHub 渲染后的正文中不会显示。

```markdown
## Motivation

<!-- Describe the purpose and goals of this pull request. -->

## Modifications

<!-- Detail the changes made in this pull request. -->

## Accuracy Tests

<!-- If this PR affects model outputs (e.g., kernel or model forward changes),
provide accuracy test results. State the test setup, commands, and results.
If not run, explain why. If not applicable, write N/A and explain why. -->

## Speed Tests and Profiling

<!-- If this PR impacts inference speed, provide benchmarking and profiling
results, including the setup, commands, and before/after comparison.
If not run, explain why. If not applicable, write N/A and explain why. -->

## Checklist

- [ ] Format your code according to [Format code with pre-commit](https://docs.sglang.io/developer_guide/contribution_guide.html#format-code-with-pre-commit).
- [ ] Add unit tests according to [Run and add unit tests](https://docs.sglang.io/developer_guide/contribution_guide.html#run-and-add-unit-tests).
- [ ] Update documentation according to [Write documentations](https://docs.sglang.io/developer_guide/contribution_guide.html#write-documentations).
- [ ] Provide accuracy and speed benchmark results according to [Test the accuracy](https://docs.sglang.io/developer_guide/contribution_guide.html#test-the-accuracy) and [Benchmark the speed](https://docs.sglang.io/developer_guide/contribution_guide.html#benchmark-the-speed).
- [ ] Follow the SGLang [code style guidance](https://docs.sglang.io/developer_guide/contribution_guide.html#code-style-guidance).
```

## Review 与合并流程

以下为 PR 提交后的协作流程；编写标题或描述本身不包含发送消息、触发 CI 或执行合并。

1. 联系 Merge Oncalls 启动流程，参见 [PR Merge Process](https://github.com/sgl-project/sglang/blob/main/.github/MAINTAINER.md#pull-request-merge-process)。
2. 获取 [CODEOWNERS](https://github.com/sgl-project/sglang/blob/main/.github/CODEOWNERS) 和其他 reviewer 的批准。
3. 按 [How to trigger CI tests](https://docs.sglang.io/developer_guide/contribution_guide.html#how-to-trigger-ci-tests) 使用评论触发 CI，或联系有权限的用户执行。常见命令：
   - `/tag-and-rerun-ci`
   - `/tag-run-ci-label`
   - `/rerun-failed-ci`
4. CI 通过且取得必要批准后，请 Merge Oncalls 或拥有 Write 权限的人员合并 PR。

如有疑问，可向维护者咨询或加入 [SGLang Slack 社区](https://slack.sglang.io)。
