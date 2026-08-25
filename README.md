# Claude Code Dispatcher

中文说明 | [English](README_EN.md)

`claude-code-dispatcher` 是一个 Codex skill，用来把具体实现任务派发给本机的 Claude Code，然后由 Codex 负责等待、复核、验证和必要时的二次修复派发。

这个 skill 的定位不是“让 Claude Code 自己决定最终质量”，而是让 Codex 作为主控方：先把任务拆清楚，再让 Claude Code 执行，最后由 Codex 检查 diff、跑验证、做 review。如果结果不够好，Codex 会继续给 Claude Code 派发更精确的修复任务。

更准确地说，它采用“组长/组员”模式：

- Codex 是组长：负责拆任务、定边界、写验收标准、review diff、跑验证和决定是否完成。
- Claude Code 是组员：负责在明确范围内做实际编码、抽取、清理和补文档。
- 目标不是让 Claude Code 永远只做小修小补，而是让它做“完整但有边界的实施切片”，由 Codex 兜底质量。

## 适用场景

- 想节约 Codex 当前会话 token，让 Claude Code 先完成一批代码或文档工作。
- 已经给 Claude Code 配好了 DeepSeek 等低成本模型，希望用它先执行、再由 Codex review。
- 需要 Codex 指挥 Claude Code 做实现，然后再由 Codex 做 code review。
- 需要把较大的任务拆成明确的业务切片、组件瘦身切片或清理切片，交给 Claude Code 执行，完成后继续迭代到满意。
- 希望把 1-10 个任务放进队列里，由 Codex 逐个派发给 Claude Code，逐个 review，通过后自动进入下一个。
- 不希望 Claude Code 自己决定最终质量，需要 Codex 独立验证结果。

## 工作方式

这个 skill 的核心流程是：

1. 如果任务只是方向或范围较大，Codex 先用 `planning-with-files` 在目标项目里写出可执行计划。
2. Codex 从计划里选择一个有边界的实施切片，检查工作区、分支、git 状态和 Claude Code CLI。
3. Codex 根据任务大小、风险和当前上下文写清楚派发 prompt。
4. Claude Code 在终端中执行任务。
5. Codex 按任务大小等待，避免频繁轮询浪费 token。
6. Claude Code 完成后，Codex 读取 diff、运行验证命令、独立 review。
7. 如果结果不好，Codex 会给 Claude Code 发精确修复任务。
8. 直到验证通过，或多次失败后由 Codex 接手/报告阻塞。

### Ponytail 方案传递边界

当上游 `loopx-engineering-manager`、`claude-terra-delivery-loop` 或权威任务包已经冻结 Ponytail 方案时，Dispatcher 只把该 contract 原样传给 Claude，不重新运行 Ponytail，也不修改强度、方案层级、非目标或简化上限。这样可以避免底层派发阶段重新决策并覆盖上游方案。

单独使用 Dispatcher 执行编码任务且没有上游 contract 时，Codex 在读完受影响链路并冻结最小架构后加载 Ponytail，按用户指定强度或默认 `full` 冻结最小充分方案；只有真正的非编码任务才记录 `none`。Dispatcher 负责传递和执行，架构、契约与验收仍由 Codex 主 Agent 持有。

## 委派实施模式

当用户的目标是节约 Codex token、加快重构或让 Claude Code 承担更多执行工作时，推荐使用委派实施模式。这个模式的原则是：**Claude Code 负责实现，Codex 负责治理**。

适合派给 Claude Code 的任务应该足够完整，能带来真实进度，例如：

- 一个业务链路：处方详情加载、提交响应处理、缓存恢复、IM 消息分类、未读/最后消息同步、自动关诊展示。
- 一个大组件瘦身切片：从 4000+ 行 Vue 文件里抽出一组相关 methods，放到 `singleDataFlow/useCases/*` 执行层。
- 一类旧逻辑清理：在新数据流读点稳定、文档和回滚点明确后，删除对应旧字段或旧兼容层。
- 一次代码和文档一致性修正：直接解锁下一步运行时代码改造，而不是只补说明。

不建议派发过小或过虚的任务，例如：

- “继续重构”但没有允许文件、验收标准和验证命令。
- 只抽一个没有风险也没有收益的小 helper。
- 高风险运行时代码删除，但没有新旧链路对比、P0 验证和回滚点。

对大组件瘦身，推荐一次抽取 5-20 个相关方法或一个完整业务区域。Vue 文件可以继续保留 `$set`、`$refs`、UI 事件和局部状态编排；纯判断、payload 构建、分支 resolver、可复用执行方法应逐步沉到 `singleDataFlow`。如果项目要求中文注释，Claude Code 必须在兼容历史行为、分支原因和副作用边界处写清楚中文注释。

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

队列可以写在目标项目的 `task_plan.md`，复杂时也可以新增 `dispatch_queue.md`。每个任务都必须是有边界的实施切片，并写清楚：

- 任务 ID 和状态
- 允许修改的文件或目录
- 禁止修改的范围
- 验收标准
- 验证命令
- 回滚点或 P0 风险

默认同一时间只运行一个 Claude Code worker。只有当前任务通过 Codex review、扫描、lint、build 或其它验证后，才会自动派发下一个任务。

注意：队列不会因为下一项要改运行时代码就停止。运行时代码改造正是这个模式的目标。只有当范围、验收标准、验证方式或 P0 风险不清楚，Codex 无法安全 review 时，队列才应该停止并补计划。

队列会在以下情况停止：

- 队列完成
- 当前任务验证失败且需要用户或外部数据
- Claude Code 修改了允许范围之外的文件
- 同一任务修复 2-3 次仍无法通过
- 下一任务缺少明确验收标准或 P0 证据
- 用户打断、暂停或改变方向

## 计划优先规则

如果用户给的是“继续重构”“拆分这个模块”“优化这个流程”这类方向性任务，Codex 不应该直接把模糊目标交给 Claude Code。更稳妥的方式是先用 `planning-with-files` 建立文件化计划，再派发单个有边界的实施切片。

计划通常记录在目标项目中：

- `task_plan.md`：阶段、任务编号、状态、验收标准、回滚点。
- `findings.md`：旧逻辑链路、新单数据流入口、分支条件、接口调用、状态变更、UI 不变项。
- `progress.md`：派发记录、Claude 执行结果、Codex review 结论、验证结果。

派发给 Claude Code 的必须是计划里的有边界实施切片。计划文件是工作记忆，不是最终指令；Codex 仍然需要在派发 prompt 中重复任务范围、约束、验证命令和不可变行为。

计划的目的不是拖慢执行，而是让 Claude Code 可以放心修改运行时代码。如果计划已经记录了旧逻辑链路、允许文件、验收点和验证命令，就应该进入实施，而不是继续反复补 readiness 文档。

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
- 有边界的业务链路改造
- 大组件瘦身和 methods 抽取
- 低风险清理和必要文档补充
- 可验证的重构步骤
- 先由 Claude Code 实现，再由 Codex review 的任务
- 需要长时间构建、测试、等待的任务
- 已经通过 `planning-with-files` 拆清楚的实施切片
- 已配置 DeepSeek 等低成本 worker 模型的执行任务
- 有明确边界、可以逐个验收的连续任务队列

## 不适合的任务类型

- 需要 Codex 立即亲自判断的高风险线上事故修复
- 缺少明确范围的大规模无边界重构
- 没有计划、没有验收标准的方向性重构
- 希望 Claude Code 不经过 Codex review 就连续跑完的大批任务
- 需要 Claude Code 自主 push 或发布的任务
- 需要绕过权限或使用 sudo 的任务
