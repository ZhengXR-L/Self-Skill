# PR 提交后的 Review 与合并流程

以下为 PR 提交后的协作流程；编写标题或描述本身不包含发送消息、触发 CI 或执行合并。

1. 联系 Merge Oncalls 启动流程，参见 [PR Merge Process](https://github.com/sgl-project/sglang/blob/main/.github/MAINTAINER.md#pull-request-merge-process)。
2. 获取 [CODEOWNERS](https://github.com/sgl-project/sglang/blob/main/.github/CODEOWNERS) 和其他 reviewer 的批准。
3. 按 [How to trigger CI tests](https://docs.sglang.io/developer_guide/contribution_guide.html#how-to-trigger-ci-tests) 使用评论触发 CI，或联系有权限的用户执行。常见命令：
   - `/tag-and-rerun-ci`
   - `/tag-run-ci-label`
   - `/rerun-failed-ci`
4. CI 通过且取得必要批准后，请 Merge Oncalls 或拥有 Write 权限的人员合并 PR。

如有疑问，可向维护者咨询或加入 [SGLang Slack 社区](https://slack.sglang.io)。