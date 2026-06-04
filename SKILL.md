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
- If Claude makes a poor change, send a focused repair prompt with exact findings; do not silently fix a large worker mistake unless it is smaller and safer for Codex to patch directly.
- Keep user updates sparse while Claude runs. When the user is conserving tokens, wait longer instead of polling frequently.

## Workflow

### 1. Preflight

Run lightweight checks before dispatch:

```bash
pwd
git branch --show-current
git status --short
command -v claude && claude --version
```

If a Claude worker from this same dispatch is still running, do not start another one. Wait for it or stop only if the user asks.

### 2. Choose Task Size and Wait Policy

Use the task size to decide how long to wait before polling:

| Size | Examples | First wait |
| --- | --- | --- |
| Small | single helper, docs update, focused lint fix | 1-2 minutes |
| Medium | one work package, 2-5 files, build/test expected | 5 minutes |
| Large | broad refactor slice, many files, build plus docs | 10-15 minutes |

After the first wait, poll every 2-5 minutes depending on expected runtime. Do not emit frequent progress messages unless the user asks for status.

### 3. Build the Dispatch Prompt

The prompt must be explicit and self-contained. Include:

- Workspace path and current branch.
- Exact task name and goal.
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

### 4. Wait Efficiently

Let the Claude process run. In Codex Desktop, use the running session and wait according to the size policy. For medium tasks, a 5-minute wait is preferred over repeated short polling when the user wants to save tokens.

If the process exits with no useful output, inspect `git status --short` and recent diffs before deciding whether it failed.

### 5. Independent Review

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

### 6. Iterate if Needed

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

## Dispatch Prompt Template

```text
Workspace:
<absolute path>

Current branch:
<branch>

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
