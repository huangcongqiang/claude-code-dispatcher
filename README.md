# Claude Code Dispatcher

## 中文说明

`claude-code-dispatcher` 是一个 Codex skill，用来把具体实现任务派发给本机的 Claude Code，然后由 Codex 负责等待、复核、验证和必要时的二次修复派发。

它适合在这些场景使用：

- 想节约 Codex 当前会话 token，让 Claude Code 先完成一批代码或文档工作。
- 需要 Codex 指挥 Claude Code 做实现，然后再由 Codex 做 code review。
- 需要把较大的任务拆成明确工作包，交给 Claude Code 执行，完成后继续迭代到满意。
- 不希望 Claude Code 自己决定最终质量，需要 Codex 独立验证结果。

### 工作方式

这个 skill 的核心流程是：

1. Codex 先检查工作区、分支、git 状态和 Claude Code CLI。
2. Codex 根据任务大小写清楚派发 prompt。
3. Claude Code 在终端中执行任务。
4. Codex 按任务大小等待，避免频繁轮询浪费 token。
5. Claude Code 完成后，Codex 读取 diff、运行验证命令、独立 review。
6. 如果结果不好，Codex 会给 Claude Code 发精确修复任务。
7. 直到验证通过，或多次失败后由 Codex 接手/报告阻塞。

### 安装

将仓库克隆到 Codex skills 目录：

```bash
git clone git@github.com:huangcongqiang/claude-code-dispatcher.git \
  ~/.codex/skills/claude-code-dispatcher
```

如果你使用 HTTPS：

```bash
git clone https://github.com/huangcongqiang/claude-code-dispatcher.git \
  ~/.codex/skills/claude-code-dispatcher
```

### 前置条件

需要本机已经安装 Claude Code CLI：

```bash
claude --version
```

如果能正常输出版本号，就可以让 Codex 使用这个 skill 派发任务。

### 使用方式

可以直接对 Codex 说：

```text
用 claude-code-dispatcher 让 Claude Code 做这批任务，完成后你来 review。
```

也可以说：

```text
为了节约 token，你来指挥 Claude Code 做实现，等他做完后你 review，不好就继续让他改。
```

### 安全边界

默认派发给 Claude Code 的任务会禁止：

- `git push`
- `git commit`
- `git reset`
- `sudo`
- 大范围 destructive 操作

除非你明确要求，否则 Codex 会保持这些限制，并在 Claude Code 完成后独立检查工作区。

### 仓库结构

```text
claude-code-dispatcher/
├── SKILL.md
├── README.md
└── agents/
    └── openai.yaml
```

### 适合的任务类型

- 单个工作包的代码实现
- 低风险清理和文档补充
- 可验证的重构步骤
- 先由 Claude Code 实现，再由 Codex review 的任务
- 需要长时间构建、测试、等待的任务

### 不适合的任务类型

- 需要 Codex 立即亲自判断的高风险线上事故修复
- 缺少明确范围的大规模无边界重构
- 需要 Claude Code 自主 push 或发布的任务
- 需要绕过权限或使用 sudo 的任务

## English

`claude-code-dispatcher` is a Codex skill for delegating implementation work to the local Claude Code CLI while keeping Codex responsible for scope, waiting, verification, review, and follow-up repair prompts.

Use it when:

- You want to save Codex conversation tokens by letting Claude Code perform a focused implementation task.
- You want Codex to dispatch work to Claude Code, then independently review the result.
- You need a larger task split into a concrete work package and iterated until acceptable.
- You do not want to rely on Claude Code's own summary as the final quality gate.

### Workflow

The skill follows this process:

1. Codex checks the workspace, branch, git state, and Claude Code CLI.
2. Codex writes a scoped dispatch prompt based on task size and risk.
3. Claude Code runs the task in the terminal.
4. Codex waits according to task size to avoid noisy polling.
5. Codex inspects the diff, runs verification commands, and reviews the result.
6. If the result is not good enough, Codex sends Claude Code a targeted repair prompt.
7. The loop stops when verification passes or repeated repair attempts hit a real blocker.

### Installation

Clone this repository into your Codex skills directory:

```bash
git clone git@github.com:huangcongqiang/claude-code-dispatcher.git \
  ~/.codex/skills/claude-code-dispatcher
```

Or with HTTPS:

```bash
git clone https://github.com/huangcongqiang/claude-code-dispatcher.git \
  ~/.codex/skills/claude-code-dispatcher
```

### Prerequisite

Claude Code CLI must be available locally:

```bash
claude --version
```

### Usage

Ask Codex:

```text
Use $claude-code-dispatcher to delegate this task to Claude Code, wait for completion, then review and iterate.
```

You can also describe the intent naturally:

```text
Please ask Claude Code to implement this, then review the result and send it back for fixes if needed.
```

### Safety Defaults

The dispatch prompt normally forbids Claude Code from running:

- `git push`
- `git commit`
- `git reset`
- `sudo`
- broad destructive operations

Codex still inspects the final diff and independently verifies the result. Claude Code's final summary is treated as input, not as proof.

### Repository Layout

```text
claude-code-dispatcher/
├── SKILL.md
├── README.md
└── agents/
    └── openai.yaml
```

### Good Fit

- Focused implementation work packages
- Low-risk cleanup and documentation updates
- Verifiable refactor slices
- Tasks where Claude Code implements and Codex reviews
- Work that benefits from long waits for builds or tests

### Poor Fit

- High-risk production incidents that require immediate Codex judgment
- Broad refactors without a clear scope
- Tasks that require Claude Code to push or deploy by itself
- Tasks requiring sudo or permission bypasses
