# Claude Code Dispatcher

[中文说明](README.md) | English

`claude-code-dispatcher` is a Codex skill for delegating implementation work to the local Claude Code CLI while keeping Codex responsible for scope, waiting, verification, review, and follow-up repair prompts.

The skill is not meant to let Claude Code decide final quality by itself. Codex remains the controller: it scopes the task, dispatches it, waits for completion, inspects the diff, runs verification, reviews the result, and sends targeted repair prompts when needed.

More precisely, it uses a technical-lead/member model:

- Codex is the technical lead. It decomposes the work, defines boundaries, writes acceptance criteria, reviews the diff, runs verification, and decides whether the task is done.
- Claude Code is the implementation member. It performs the actual coding, extraction, cleanup, and documentation inside the assigned scope.
- The goal is not to make Claude Code do tiny cautious edits forever. The goal is to let it complete meaningful, bounded implementation slices while Codex owns the quality gate.

## When To Use

- You want to save Codex conversation tokens by letting Claude Code perform a focused implementation task.
- Claude Code is already configured with DeepSeek or another lower-cost model, and you want it to execute before Codex reviews.
- You want Codex to dispatch work to Claude Code, then independently review the result.
- You need a larger task split into concrete business, component-slimming, or cleanup slices and iterated until acceptable.
- You want to place 1-10 tasks into a queue, have Codex dispatch them to Claude Code one by one, review each result, then automatically continue to the next accepted task.
- You do not want to rely on Claude Code's own summary as the final quality gate.

## Workflow

The skill follows this process:

1. If the task is broad or only directional, Codex first uses `planning-with-files` to create an executable plan in the target project.
2. Codex selects one bounded implementation slice from the plan, then checks the workspace, branch, git state, and Claude Code CLI.
3. Codex writes a scoped dispatch prompt based on task size, risk, and current context.
4. Claude Code runs the task in the terminal.
5. Codex waits according to task size to avoid noisy polling.
6. Codex inspects the diff, runs verification commands, and reviews the result.
7. If the result is not good enough, Codex sends Claude Code a targeted repair prompt.
8. The loop stops when verification passes or repeated repair attempts hit a real blocker.

## Delegated Implementation Mode

When the user wants to save Codex tokens, accelerate refactoring, or let Claude Code carry more of the implementation load, use delegated implementation mode. The principle is: **Claude Code implements, Codex governs.**

Good Claude-sized tasks are complete enough to create real progress, for example:

- One business chain: prescription detail loading, submit response handling, cache restore, IM message classification, unread/last-message sync, or automatic-close display.
- One large-component slimming slice: extracting a cohesive group of methods from a 4000+ line Vue file into a `singleDataFlow/useCases/*` execution-layer file.
- One legacy cleanup class: removing a legacy field or compatibility layer after the new data-flow read points, documentation, and rollback notes are clear.
- One code-and-documentation consistency pass that directly unlocks the next runtime refactor.

Poor Claude-sized tasks are either too vague or too small, for example:

- "Continue the refactor" without allowed files, acceptance criteria, and verification commands.
- Extracting one trivial helper that does not reduce coupling or line count meaningfully.
- Deleting high-risk runtime code without old/new flow comparison, P0 verification, or rollback notes.

For large component slimming, prefer extracting 5-20 related methods or one complete business area at a time. The Vue file can still keep orchestration that needs `$set`, `$refs`, UI events, and local component state. Pure decisions, payload builders, branch resolvers, and reusable execution methods should gradually move into `singleDataFlow`. If the project requires Chinese comments, Claude Code must explain historical compatibility, branch reasons, and side-effect boundaries in Chinese comments.

## Continuous Task Queue

This skill supports continuous tasks, but not unattended bulk execution by Claude Code. The recommended model is "serial automation with review gates":

```text
Task 1 -> dispatch Claude -> Codex review/verification
  -> pass: mark Done and automatically start Task 2
  -> fail: dispatch a focused repair; after repeated failures, mark Blocked and stop

Task 2 -> dispatch Claude -> Codex review/verification
...
until the queue is complete or blocked
```

The queue can live in the target project's `task_plan.md`; use `dispatch_queue.md` only when the queue needs more detail. Each task must be a bounded implementation slice and include:

- task ID and status
- allowed files or directories
- forbidden scope
- acceptance criteria
- verification commands
- rollback point or P0 risk

By default, only one Claude Code worker runs at a time. The next task is dispatched only after Codex has reviewed the diff and passed the required scans, lint, build, or other verification for the current task.

Important: the queue should not stop merely because the next item touches runtime code. Runtime refactoring is the point of this mode. Stop only when scope, acceptance criteria, verification, or P0 risk is unclear enough that Codex cannot review safely.

The queue stops when:

- the queue is complete
- the current task fails verification and needs user or external input
- Claude Code changes files outside the allowed scope
- the same task still fails after 2-3 repair attempts
- the next task lacks clear acceptance criteria or required P0 evidence
- the user interrupts, pauses, or changes direction

## Planning-First Rule

When the user gives a direction such as "continue the refactor", "split this module", or "optimize this flow", Codex should not hand a vague goal directly to Claude Code. The safer pattern is to use `planning-with-files` first, then dispatch a single bounded implementation slice.

The plan normally lives in the target project:

- `task_plan.md`: phases, task IDs, status, acceptance criteria, rollback points.
- `findings.md`: old logic chain, new data-flow entry, branch conditions, API calls, state mutations, UI invariants.
- `progress.md`: dispatch history, Claude result, Codex review conclusion, verification result.

Claude Code should receive a bounded implementation slice from the plan. The planning files are working memory, not a replacement for an executable dispatch prompt; Codex should still repeat the exact scope, constraints, verification commands, and behavior that must remain unchanged.

Planning should enable execution, not delay it. If the plan already records the old logic chain, allowed files, acceptance criteria, and verification commands, Codex should dispatch Claude Code to modify runtime code instead of repeatedly adding readiness-only documentation.

## Cost Control

If the local Claude Code setup already uses DeepSeek or another lower-cost model, it can be used as the execution worker for implementation, cleanup, and documentation tasks. This skill does not explain or modify Claude Code model configuration; it assumes the model is already configured and focuses on dispatching, waiting, diff review, and repair prompts.

The lower-cost model only does the work. Codex still decides whether the result passes review, verification, and business-logic comparison.

## Installation

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

## Prerequisite

Claude Code CLI must be available locally:

```bash
claude --version
```

If the command prints a version number, Codex can use this skill to dispatch work to Claude Code.

## Usage

Ask Codex:

```text
Use claude-code-dispatcher to delegate this task to Claude Code, wait for completion, then review and iterate.
```

You can also describe the intent naturally:

```text
Please ask Claude Code to implement this, then review the result and send it back for fixes if needed.
```

## Safety Defaults

The dispatch prompt normally forbids Claude Code from running:

- `git push`
- `git commit`
- `git reset`
- `sudo`
- broad destructive operations

Unless you explicitly ask otherwise, Codex keeps these restrictions in place and independently checks the workspace after Claude Code finishes. Claude Code's final summary is treated as input, not proof.

## Repository Layout

```text
claude-code-dispatcher/
├── SKILL.md
├── README.md
├── README_EN.md
└── agents/
    └── openai.yaml
```

## Good Fit

- Focused implementation work packages
- Bounded business-flow refactors
- Large-component slimming and method extraction
- Low-risk cleanup and necessary documentation updates
- Verifiable refactor slices
- Tasks where Claude Code implements and Codex reviews
- Work that benefits from long waits for builds or tests
- Implementation slices that have already been broken down with `planning-with-files`
- Execution tasks where Claude Code already has a lower-cost worker model configured
- Continuous task queues with clear boundaries and per-task acceptance checks

## Poor Fit

- High-risk production incidents that require immediate Codex judgment
- Broad refactors without a clear scope
- Directional refactors without a plan or acceptance criteria
- Bulk task execution where Claude Code runs many tasks without Codex review between them
- Tasks that require Claude Code to push or deploy by itself
- Tasks requiring sudo or permission bypasses
