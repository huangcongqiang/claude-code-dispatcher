---
name: claude-code-dispatcher
description: Use when the user wants Codex to delegate implementation or cleanup work to Claude Code from the terminal, wait for completion, review the result, and send follow-up fix prompts until the work is acceptable. Triggers include "让 Claude Code 做", "指挥 Claude", "用 claude 派任务", "节约 token", "让 deepseek/Claude 先做我再 review", or requests to continue work through Claude Code.
---

# Claude Code Dispatcher

## Purpose

Use Claude Code as a worker process while Codex stays responsible for scoping, verification, review, and final judgment. Claude may edit files, but Codex owns the dispatch prompt, waits efficiently, independently reviews the result, and asks Claude for targeted fixes when needed.

## Core Rules

- Start at most one Claude Code worker for a task unless the user explicitly asks for parallel workers.
- Do not trust Claude's summary. Always inspect the diff and run independent verification.
- Default to no `git push`, no `git commit`, no destructive git operations, and no broad checkout/reset.
- Preserve user changes. If unrelated dirty files exist, ignore them unless they affect the task.
- If the task is risky, narrow it before dispatching: one work package, one feature slice, or one cleanup class.
- For broad direction-setting tasks, use `planning-with-files` first: write the executable plan in the target project, then dispatch only one leaf task from that plan.
- If Claude Code has already been configured to use DeepSeek or another low-cost model, it is a good worker choice for execution. Do not manage model setup inside this skill; Codex still owns review and final judgment.
- If Claude makes a poor change, send a focused repair prompt with exact findings; do not silently fix a large worker mistake unless it is smaller and safer for Codex to patch directly.
- Keep user updates sparse while Claude runs. When the user is conserving tokens, wait longer instead of polling frequently.
- Continuous work is allowed only as a controlled queue: run one Claude worker at a time, review the result, update the queue state, then dispatch the next queued leaf task if the previous one passed.

## Workflow

### 1. Planning Gate

Before dispatching, decide whether the user's request is already an executable task or only a direction.

Use `planning-with-files` first when the task has any of these traits:

- It touches multiple business chains, domains, or large components.
- It requires more than a small focused edit, or likely needs many tool calls.
- It has high regression risk, such as prescription submission, IM messages, unread counts, caching, or cleanup of old runtime logic.
- The user gives a direction like "continue the refactor", "split this module", or "optimize this flow" without exact files and acceptance criteria.

When planning is needed, create or update the target project's plan files before starting Claude:

- `task_plan.md`: phases, task IDs, statuses, acceptance criteria, rollback points.
- `findings.md`: old logic chain, new data-flow entry, branch conditions, API calls, state mutations, UI invariants.
- `progress.md`: dispatch history, Claude results, Codex review findings, verification results.

The dispatchable unit should be a leaf task from the plan. Do not ask Claude to handle a vague direction. The prompt should point to the relevant plan section but still repeat the exact scope and constraints, because plan files are memory, not a substitute for an executable dispatch prompt.

### Continuous Queue Mode

Use this mode when the user explicitly asks for continuous tasks, a task queue, or wording like "1-10 tasks, review each one, then automatically start the next."

Continuous queue mode means **serial automation with review gates**, not parallel or unattended delegation:

1. Create or update a bounded queue in the target project's planning files. Use an existing `task_plan.md` table when possible; add a `dispatch_queue.md` only when the queue needs extra detail.
2. Each queue item must be a leaf task with:
   - task ID and status
   - allowed files or directories
   - forbidden changes
   - acceptance criteria
   - verification commands
   - rollback point
3. Dispatch only the first eligible item with status `Not Started` or `Ready`.
4. After Claude finishes, independently review the diff and run verification before changing the item to `Done`.
5. If review passes, update `progress.md` and automatically continue to the next queued item.
6. If review fails, mark the item `Fixing`, send Claude one focused repair prompt, and repeat review.
7. Stop the queue and report status when:
   - the queue is empty
   - a task is `Blocked`
   - the same task fails after 2-3 repair attempts
   - Claude touches files outside the allowed scope
   - verification fails for a reason that needs user or external input
   - the next item is high risk and lacks acceptance criteria or P0 evidence
   - the user interrupts, pauses, or changes direction

Keep the invariant: at most one Claude Code process is active for this queue unless the user explicitly asks for parallel workers.

### Cost-Aware Worker Model

When Claude Code is already configured with DeepSeek or another lower-cost model, prefer using that configured model for implementation, cleanup, and documentation work. The model is only the worker; Codex must still inspect the diff, run verification, and decide whether the result is acceptable.

Do not turn this skill into a model-setup guide. If the configured model is unavailable, fall back to the local Claude Code default or ask the user to fix Claude Code's model configuration.

### 2. Preflight

Run lightweight checks before dispatch:

```bash
pwd
git branch --show-current
git status --short
command -v claude && claude --version
```

If a Claude worker from this same dispatch is still running, do not start another one. Wait for it or stop only if the user asks.

### 3. Choose Task Size and Wait Policy

Use the task size to decide how long to wait before polling:

| Size | Examples | First wait |
| --- | --- | --- |
| Small | single helper, docs update, focused lint fix | 1-2 minutes |
| Medium | one work package, 2-5 files, build/test expected | 5 minutes |
| Large | broad refactor slice, many files, build plus docs | 10-15 minutes |

After the first wait, poll every 2-5 minutes depending on expected runtime. Do not emit frequent progress messages unless the user asks for status.

### 4. Build the Dispatch Prompt

The prompt must be explicit and self-contained. Include:

- Workspace path and current branch.
- Exact task name and goal.
- Plan reference when using `planning-with-files`: file path, task ID, and the specific section Claude should follow.
- Hard constraints: no push/commit/reset, no UI/interaction change unless requested, do not touch build artifacts, preserve existing user changes.
- Allowed scope and files/directories.
- Expected comments/documentation requirements.
- Verification commands.
- Required final output: changed files, verification result, risks, next steps.

Use this command shape for non-interactive dispatch:

```bash
claude -p --permission-mode acceptEdits \
  --disallowedTools 'Bash(git push *)' 'Bash(git commit *)' 'Bash(git reset *)' 'Bash(sudo *)' \
  --effort high <<'PROMPT'
...task prompt...
PROMPT
```

Add more `--disallowedTools` entries for task-specific hazards, such as deploy commands or broad file deletes. If the task only needs analysis, use `--permission-mode default` and forbid edit tools.

### 5. Wait Efficiently

Let the Claude process run. In Codex Desktop, use the running session and wait according to the size policy. For medium tasks, a 5-minute wait is preferred over repeated short polling when the user wants to save tokens.

If the process exits with no useful output, inspect `git status --short` and recent diffs before deciding whether it failed.

### 6. Independent Review

After Claude finishes:

1. Read Claude's final summary.
2. Inspect changed files:

```bash
git status --short
git diff --stat
git diff -- <relevant files>
```

3. Run or repeat verification independently. Use the project's known commands, not only Claude's claims.
4. Restore known build side effects when appropriate, for example:

```bash
git restore -- public/version.js
```

5. If Claude added review helpers or sample runners, execute them if practical. If direct execution needs transpilation, use a temporary in-memory script rather than adding project files unless the task asks for test infrastructure.

Review with findings first:

- Blocking runtime or logic bugs.
- Verification gaps or false documentation.
- Over-broad edits, artifact churn, or changed UI/interaction.
- Missing comments where the user explicitly requested detailed comments.
- Mismatch with the planning file's old-logic chain, branch conditions, or acceptance criteria.

If the task used `planning-with-files`, update `progress.md` after review. If a phase is complete, update `task_plan.md`; if new old-logic details or risks were discovered, update `findings.md`.

For continuous queue mode, also update the queue item status after each review:

- `Not Started`: not yet dispatched
- `In Progress`: currently assigned to Claude
- `Review`: Claude finished and Codex is checking it
- `Fixing`: repair prompt sent after review findings
- `Done`: Codex verified and accepted it
- `Blocked`: cannot continue safely without user input or external state
- `Skipped`: intentionally skipped with a recorded reason

### 7. Iterate if Needed

If the result is not satisfactory, send a repair prompt to Claude with:

- Exact file and line references.
- What is wrong.
- What to change.
- What not to touch.
- Verification commands to rerun.

Use a tighter prompt than the original. Do not ask Claude to "review itself"; ask it to fix specific findings.

Stop the loop when:

- Verification passes and review has no blocking findings, or
- The same issue fails after 2-3 repair attempts, at which point Codex should either patch directly or report the blocker.

In continuous queue mode, this "stop" applies to the current queue item. If the item reaches `Done`, continue to the next queued item automatically. If the item reaches `Blocked`, stop the whole queue and summarize what was completed, what failed, and the next safe action.

## Continuous Queue Template

Use this compact queue table inside `task_plan.md` or `dispatch_queue.md`:

```markdown
| Order | Task ID | Goal | Allowed Scope | Verification | Status | Notes |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | T01 | <one leaf task> | <files/dirs> | <commands> | Not Started | <rollback/P0 notes> |
| 2 | T02 | <one leaf task> | <files/dirs> | <commands> | Not Started | <rollback/P0 notes> |
```

Dispatch cycle:

```text
select next Not Started/Ready item
mark In Progress
dispatch Claude
wait by task size
mark Review
inspect diff + run verification
if pass: mark Done and continue
if fail: mark Fixing and send focused repair prompt
if still fail or unsafe: mark Blocked and stop queue
```

## Dispatch Prompt Template

```text
Workspace:
<absolute path>

Current branch:
<branch>

Plan reference:
<task_plan.md path / task ID / relevant findings.md section, or "none">

Task:
<WP/name>

Goal:
<one paragraph>

Hard constraints:
1. Do not push or commit.
2. Do not run destructive git commands.
3. Do not change UI/interaction unless explicitly requested.
4. Preserve user changes and unrelated dirty files.
5. Keep the scope to <files/areas>.
6. Add clear comments where historical behavior or compatibility is easy to misunderstand.
7. Restore build artifacts such as public/version.js if validation changes them.

Implementation:
<concrete steps>

Verification:
<commands>

Final output:
- Changed files
- Verification results
- Logic risks found
- Remaining work
```

## Final Response to User

After reviewing Claude's work, tell the user:

- Whether Claude's result passed review.
- What changed.
- What you independently verified.
- Any issues you fixed or asked Claude to fix.
- What remains unfinished.

Do not present Claude's summary as fact unless Codex has checked it.
