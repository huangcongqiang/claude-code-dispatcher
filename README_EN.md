# Claude Code Dispatcher

[中文说明](README.md) | English

`claude-code-dispatcher` is a Codex skill for delegating implementation work to the local Claude Code CLI while keeping Codex responsible for scope, waiting, verification, review, and follow-up repair prompts.

The skill is not meant to let Claude Code decide final quality by itself. Codex remains the controller: it scopes the task, dispatches it, waits for completion, inspects the diff, runs verification, reviews the result, and sends targeted repair prompts when needed.

## When To Use

- You want to save Codex conversation tokens by letting Claude Code perform a focused implementation task.
- Claude Code is already configured with DeepSeek or another lower-cost model, and you want it to execute before Codex reviews.
- You want Codex to dispatch work to Claude Code, then independently review the result.
- You need a larger task split into a concrete work package and iterated until acceptable.
- You do not want to rely on Claude Code's own summary as the final quality gate.

## Workflow

The skill follows this process:

1. If the task is broad or only directional, Codex first uses `planning-with-files` to create an executable plan in the target project.
2. Codex selects one leaf task from the plan, then checks the workspace, branch, git state, and Claude Code CLI.
3. Codex writes a scoped dispatch prompt based on task size, risk, and current context.
4. Claude Code runs the task in the terminal.
5. Codex waits according to task size to avoid noisy polling.
6. Codex inspects the diff, runs verification commands, and reviews the result.
7. If the result is not good enough, Codex sends Claude Code a targeted repair prompt.
8. The loop stops when verification passes or repeated repair attempts hit a real blocker.

## Planning-First Rule

When the user gives a direction such as "continue the refactor", "split this module", or "optimize this flow", Codex should not hand a vague goal directly to Claude Code. The safer pattern is to use `planning-with-files` first, then dispatch a single executable task.

The plan normally lives in the target project:

- `task_plan.md`: phases, task IDs, status, acceptance criteria, rollback points.
- `findings.md`: old logic chain, new data-flow entry, branch conditions, API calls, state mutations, UI invariants.
- `progress.md`: dispatch history, Claude result, Codex review conclusion, verification result.

Claude Code should receive a leaf task from the plan. The planning files are working memory, not a replacement for an executable dispatch prompt; Codex should still repeat the exact scope, constraints, verification commands, and behavior that must remain unchanged.

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
- Low-risk cleanup and documentation updates
- Verifiable refactor slices
- Tasks where Claude Code implements and Codex reviews
- Work that benefits from long waits for builds or tests
- Leaf tasks that have already been broken down with `planning-with-files`
- Execution tasks where Claude Code already has a lower-cost worker model configured

## Poor Fit

- High-risk production incidents that require immediate Codex judgment
- Broad refactors without a clear scope
- Directional refactors without a plan or acceptance criteria
- Tasks that require Claude Code to push or deploy by itself
- Tasks requiring sudo or permission bypasses
