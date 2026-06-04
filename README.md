# Claude Code Dispatcher

中文说明 | [English](README_EN.md)

`claude-code-dispatcher` 是一个 Codex skill，用来把具体实现任务派发给本机的 Claude Code，然后由 Codex 负责等待、复核、验证和必要时的二次修复派发。

这个 skill 的定位不是“让 Claude Code 自己决定最终质量”，而是让 Codex 作为主控方：先把任务拆清楚，再让 Claude Code 执行，最后由 Codex 检查 diff、跑验证、做 review。如果结果不够好，Codex 会继续给 Claude Code 派发更精确的修复任务。

## 适用场景

- 想节约 Codex 当前会话 token，让 Claude Code 先完成一批代码或文档工作。
- 已经给 Claude Code 配好了 DeepSeek 等低成本模型，希望用它先执行、再由 Codex review。
- 需要 Codex 指挥 Claude Code 做实现，然后再由 Codex 做 code review。
- 需要把较大的任务拆成明确工作包，交给 Claude Code 执行，完成后继续迭代到满意。
- 希望把 1-10 个任务放进队列里，由 Codex 逐个派发给 Claude Code，逐个 review，通过后自动进入下一个。
- 不希望 Claude Code 自己决定最终质量，需要 Codex 独立验证结果。

## 工作方式

这个 skill 的核心流程是：

1. 如果任务只是方向或范围较大，Codex 先用 `planning-with-files` 在目标项目里写出可执行计划。
2. Codex 从计划里选择一个叶子任务，检查工作区、分支、git 状态和 Claude Code CLI。
3. Codex 根据任务大小、风险和当前上下文写清楚派发 prompt。
4. Claude Code 在终端中执行任务。
5. Codex 按任务大小等待，避免频繁轮询浪费 token。
6. Claude Code 完成后，Codex 读取 diff、运行验证命令、独立 review。
7. 如果结果不好，Codex 会给 Claude Code 发精确修复任务。
8. 直到验证通过，或多次失败后由 Codex 接手/报告阻塞。

## 连续任务队列

这个 skill 支持连续任务，但不是让 Claude Code 无人值守地一次性跑完整串任务。推荐模式是“串行自动化 + review gate”：

```text
任务 1 -> 派发 Claude -> Codex review/验证
  -> 通过：标记 Done，自动开始任务 2
  -> 不通过：派发精确修复；多次失败后标记 Blocked 并停止队列

任务 2 -> 派发 Claude -> Codex review/验证
...
直到队列完成或遇到阻塞
```

队列可以写在目标项目的 `task_plan.md`，复杂时也可以新增 `dispatch_queue.md`。每个任务都必须是叶子任务，并写清楚：

- 任务 ID 和状态
- 允许修改的文件或目录
- 禁止修改的范围
- 验收标准
- 验证命令
- 回滚点或 P0 风险

默认同一时间只运行一个 Claude Code worker。只有当前任务通过 Codex review、扫描、lint、build 或其它验证后，才会自动派发下一个任务。

队列会在以下情况停止：

- 队列完成
- 当前任务验证失败且需要用户或外部数据
- Claude Code 修改了允许范围之外的文件
- 同一任务修复 2-3 次仍无法通过
- 下一任务缺少明确验收标准或 P0 证据
- 用户打断、暂停或改变方向

## 计划优先规则

如果用户给的是“继续重构”“拆分这个模块”“优化这个流程”这类方向性任务，Codex 不应该直接把模糊目标交给 Claude Code。更稳妥的方式是先用 `planning-with-files` 建立文件化计划，再派发单个可执行任务。

计划通常记录在目标项目中：

- `task_plan.md`：阶段、任务编号、状态、验收标准、回滚点。
- `findings.md`：旧逻辑链路、新单数据流入口、分支条件、接口调用、状态变更、UI 不变项。
- `progress.md`：派发记录、Claude 执行结果、Codex review 结论、验证结果。

派发给 Claude Code 的必须是计划里的叶子任务。计划文件是工作记忆，不是最终指令；Codex 仍然需要在派发 prompt 中重复任务范围、约束、验证命令和不可变行为。

## 成本控制

如果本机 Claude Code 已经配置了 DeepSeek 或其他低成本模型，可以把它作为执行 worker 使用，适合做实现、清理和文档类任务。这个 skill 不负责讲解或修改 Claude Code 的模型配置，只负责在模型已配置好的前提下派发任务、等待结果、review diff 和继续修复派发。

低成本模型只负责“做”，最终是否通过仍由 Codex 的 review、验证命令和业务逻辑对比决定。

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
- 已经通过 `planning-with-files` 拆清楚的叶子任务
- 已配置 DeepSeek 等低成本 worker 模型的执行任务
- 有明确边界、可以逐个验收的连续任务队列

## 不适合的任务类型

- 需要 Codex 立即亲自判断的高风险线上事故修复
- 缺少明确范围的大规模无边界重构
- 没有计划、没有验收标准的方向性重构
- 希望 Claude Code 不经过 Codex review 就连续跑完的大批任务
- 需要 Claude Code 自主 push 或发布的任务
- 需要绕过权限或使用 sudo 的任务
