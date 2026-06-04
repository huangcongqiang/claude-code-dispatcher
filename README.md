# Claude Code Dispatcher

中文说明 | [English](README_EN.md)

`claude-code-dispatcher` 是一个 Codex skill，用来把具体实现任务派发给本机的 Claude Code，然后由 Codex 负责等待、复核、验证和必要时的二次修复派发。

这个 skill 的定位不是“让 Claude Code 自己决定最终质量”，而是让 Codex 作为主控方：先把任务拆清楚，再让 Claude Code 执行，最后由 Codex 检查 diff、跑验证、做 review。如果结果不够好，Codex 会继续给 Claude Code 派发更精确的修复任务。

## 适用场景

- 想节约 Codex 当前会话 token，让 Claude Code 先完成一批代码或文档工作。
- 需要 Codex 指挥 Claude Code 做实现，然后再由 Codex 做 code review。
- 需要把较大的任务拆成明确工作包，交给 Claude Code 执行，完成后继续迭代到满意。
- 不希望 Claude Code 自己决定最终质量，需要 Codex 独立验证结果。

## 工作方式

这个 skill 的核心流程是：

1. Codex 先检查工作区、分支、git 状态和 Claude Code CLI。
2. Codex 根据任务大小、风险和当前上下文写清楚派发 prompt。
3. Claude Code 在终端中执行任务。
4. Codex 按任务大小等待，避免频繁轮询浪费 token。
5. Claude Code 完成后，Codex 读取 diff、运行验证命令、独立 review。
6. 如果结果不好，Codex 会给 Claude Code 发精确修复任务。
7. 直到验证通过，或多次失败后由 Codex 接手/报告阻塞。

## 安装

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

## 前置条件

需要本机已经安装 Claude Code CLI：

```bash
claude --version
```

如果能正常输出版本号，就可以让 Codex 使用这个 skill 派发任务。

## 使用方式

可以直接对 Codex 说：

```text
用 claude-code-dispatcher 让 Claude Code 做这批任务，完成后你来 review。
```

也可以说：

```text
为了节约 token，你来指挥 Claude Code 做实现，等他做完后你 review，不好就继续让他改。
```

## 安全边界

默认派发给 Claude Code 的任务会禁止：

- `git push`
- `git commit`
- `git reset`
- `sudo`
- 大范围 destructive 操作

除非你明确要求，否则 Codex 会保持这些限制，并在 Claude Code 完成后独立检查工作区。Claude Code 的总结只能作为参考，不能替代 Codex 的最终验证。

## 仓库结构

```text
claude-code-dispatcher/
├── SKILL.md
├── README.md
├── README_EN.md
└── agents/
    └── openai.yaml
```

## 适合的任务类型

- 单个工作包的代码实现
- 低风险清理和文档补充
- 可验证的重构步骤
- 先由 Claude Code 实现，再由 Codex review 的任务
- 需要长时间构建、测试、等待的任务

## 不适合的任务类型

- 需要 Codex 立即亲自判断的高风险线上事故修复
- 缺少明确范围的大规模无边界重构
- 需要 Claude Code 自主 push 或发布的任务
- 需要绕过权限或使用 sudo 的任务
