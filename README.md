# Self-Skill

给 agent（Trae、Codex 等）使用的 SGLang 工作技能库。每个技能是一个目录，核心文件是 `SKILL.md`；`examples/` 放原始脚本与重构示例，不作为技能加载。

## 技能列表

| 技能 | 用途 | 典型触发 | 依赖 |
| --- | --- | --- | --- |
| `sglang-single-request` | 起服务 + 发一个请求，确认模型能起来、能出字 | 「确认模型能跑」「排查启动失败」 | NPU、模型权重、SGLang |
| `sglang-gsm8k-accuracy` | GSM8K 精度回归用例的写法与阈值约定 | 「跑一下 GSM8K 精度」「新增精度用例」 | SGLang 仓库测试框架、NPU |
| `sglang-benchmark` | 用 `sglang.bench_serving` 做 TTFT/吞吐/前缀缓存压测 | 「压测一下 TTFT」「性能有没有退化」 | SGLang、NPU 或可访问的服务端 |
| `sglang-test-script` | 特性复现脚本的交付结构与规范 | 「给我写个复现脚本」「整理测试脚本」 | bash、NPU |
| `sglang-pr` | SGLang PR 标题与描述的格式要求 | 「提个 PR」「检查 PR 描述」 | 无 |

## 怎么选

| 用户说法 | 命中技能 |
| --- | --- |
| 确认模型能出字、服务起不来 | `sglang-single-request` |
| 跑 GSM8K、精度掉没掉、精度阈值 | `sglang-gsm8k-accuracy` |
| TTFT、吞吐、并发、bench_serving、性能回归 | `sglang-benchmark` |
| 写复现脚本、测试脚本怎么组织、环境变量放哪 | `sglang-test-script` |
| PR 标题格式、PR 描述模板 | `sglang-pr` |

新增技能时先在上表补一行，避免多个技能的触发词重叠。

## 安装

全局安装到 `%USERPROFILE%\.trae-cn\skills`，Windows 11 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

| 参数 | 说明 |
| --- | --- |
| `-Link` | 用目录联接（junction）代替复制，仓库改动立即生效，无需管理员 |
| `-Force` | 覆盖已安装的同名技能 |
| `-DryRun` | 只打印将执行的动作，不写文件 |
| `-List` | 只列出可安装技能 |
| `-Dest <path>` | 自定义安装目录，默认 `%USERPROFILE%\.trae-cn\skills` |

安装后新开一个会话生效。卸载直接删除目标目录下的对应技能文件夹。

在 Trae 的沙箱终端里执行时请用复制模式（不加 `-Link`）：沙箱会重定向盘符，junction 目标会指向沙箱缓存路径而不是仓库真实路径。

在 macOS / Linux 上手工复制即可：

```bash
mkdir -p ~/.trae-cn/skills
cp -r skills/* ~/.trae-cn/skills/
```

## 目录结构

```text
.
├── skills/                            # 可被 agent 加载的技能，一个目录一个 SKILL.md
│   ├── sglang-single-request/
│   ├── sglang-gsm8k-accuracy/
│   ├── sglang-benchmark/
│   ├── sglang-test-script/
│   └── sglang-pr/
├── examples/                          # 原始脚本与重构示例，不参与安装
│   ├── dsv4_lf_kv_split_e2e/
│   └── dsv4_lf_kv_split_e2e_refactor/
├── install.ps1
└── README.md
```

## 新增技能约定

1. 目录名与 frontmatter 的 `name` 完全一致，统一 `sglang-` 前缀。
2. `description` 三段式：做什么 + `Use when` 触发条件（含中文说法）+ `Do not use for` 排除项。
3. 正文只写该领域 agent 不知道的约定，长文档放 `references/`，长模板放 `assets/`。
4. 配置集中在一个 `env.sh`，模型路径、卡号、端口不写死；服务统一用 `sglang serve`，不加 `exec`。
5. 交付前对照正文末尾的检查清单逐条核对。
