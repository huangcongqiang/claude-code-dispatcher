---
name: claude-code-dispatcher
description: Use when the user wants Codex to delegate terminal implementation, cleanup, or review work to Claude Code, including plans with independent parallel tasks, multiple Claude workers, or isolated git worktrees.
---

# Claude Code Dispatcher

## Purpose

Use Claude Code as a worker process while Codex stays responsible for scoping, verification, review, and final judgment. Claude may edit files, but Codex owns the dispatch prompt, waits efficiently, independently reviews the result, and asks Claude for targeted fixes when needed.

Think of the relationship as **technical lead and implementation member**:

- Codex is the lead. Codex decomposes the work, defines boundaries, chooses the acceptance criteria, reviews the diff, runs verification, and decides whether the work is done.
- Claude Code is the implementation member. Claude should do the actual coding, extraction, cleanup, and documentation inside the assigned scope, including runtime code changes when the task calls for them.
- A good dispatch is not "ask Claude to be careful"; it is "give Claude a complete, bounded implementation slice with clear invariants and let it execute."

## Core Rules

- Default to one Claude Code worker. Multiple workers are allowed only through **Parallel Wave Mode** after Codex proves the planned items are independent and isolates every mutable resource they could share. A request for speed permits considering parallelism; it does not prove safety.
- Run at most one worker per queue item. Default parallel wave size is 2; increase up to 4 only after checking CPU, memory, build directories, ports, databases, and integration capacity. A larger wave requires explicit user direction and the same safety gate.
- Do not trust Claude's summary. Always inspect the diff and run independent verification.
- Default to no `git push`, no `git commit`, no destructive git operations, and no broad checkout/reset.
- Preserve user changes. If unrelated dirty files exist, ignore them unless they affect the task.
- Runtime code changes are allowed when the assigned task is an implementation or refactor slice. Do not restrict Claude to documentation/readiness work unless the user explicitly asks for analysis only.
- If the task is risky, narrow it to one cohesive business slice, feature flow, component extraction, or cleanup class. Do not shrink it so far that progress becomes cosmetic.
- For broad direction-setting tasks, use `planning-with-files` first: write the executable plan in the target project, then dispatch one bounded implementation slice from that plan.
- If Claude Code has already been configured to use DeepSeek or another low-cost model, it is a good worker choice for execution. Do not manage model setup inside this skill; Codex still owns review and final judgment.
- If Claude makes a poor change, send a focused repair prompt with exact findings; do not silently fix a large worker mistake unless it is smaller and safer for Codex to patch directly.
- Keep user updates sparse while Claude runs. When the user is conserving tokens, wait longer instead of polling frequently.
- Continuous work is allowed as a controlled queue. Execute serially by default; dispatch a bounded parallel wave only when every ready item passes the Parallel Wave gate.
- Prefer fewer, larger, well-bounded tasks over many tiny tasks when the user wants real refactor progress and Codex can review the result.

## Managed Delegated Implementation Mode

Use this mode when the user wants to save Codex tokens, accelerate refactoring, or says Claude Code should be the worker while Codex reviews.

The default posture in this mode is: **Claude implements, Codex governs.**

Good Claude-sized tasks:

- One business chain, such as prescription detail loading, submit response handling, cache restore, IM message classification, unread/last-message sync, or automatic-close display.
- One large-component slimming slice, such as extracting a cohesive method group from a 4000+ line Vue file into a `singleDataFlow/useCases/*` execution-layer file.
- One cleanup class, such as removing a legacy field only after the new data-flow read points are stable and documented.
- One documentation-and-code consistency pass when it directly unlocks the next runtime change.

Poor Claude-sized tasks:

- "Continue the refactor" without allowed files, acceptance criteria, or verification.
- A single trivial helper extraction that does not reduce coupling or line count meaningfully.
- A high-risk production deletion without old/new logic comparison, rollback notes, or P0 verification expectations.

For large component slimming, do not dispatch work as "move one method" unless the method is unusually risky. Dispatch a cohesive group instead:

- Extract 5-20 related methods or one UI/business section at a time.
- Keep the Vue component as the orchestration surface only when it still needs `$set`, `$refs`, UI events, or local component state.
- Move pure decision logic, payload building, branch resolution, and reusable execution methods into `singleDataFlow` files.
- Require Chinese comments when the user/project asks for Chinese comments. Comments should explain historical compatibility, branch reasons, and why UI-side side effects remain in the component.
- Require Claude to report original line count, new line count, changed files, verification result, and remaining risks.

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

The dispatchable unit should be a bounded implementation slice from the plan. Do not ask Claude to handle a vague direction. The prompt should point to the relevant plan section but still repeat the exact scope and constraints, because plan files are memory, not a substitute for an executable dispatch prompt.

Planning should enable execution, not delay it. If the plan already identifies the old logic chain, allowed files, invariants, and verification, dispatch Claude to modify runtime code instead of creating another readiness-only artifact.

### Parallel Wave Mode

Use a parallel wave only for two or more `Ready` plan items that can complete and be reviewed independently. Before starting processes, record a dependency and ownership table. Every row must include:

- worker ID and task ID
- `depends_on` task IDs and wave number
- exact allowed read/write paths
- shared interfaces, schemas, migrations, generated files, and external services
- worktree path and base SHA, or the explicit reason a shared worktree is safe
- build output, port, database/schema, temp directory, and cache ownership
- focused verification and integration order

All of these gates must be true:

1. No task consumes another task's unintegrated output.
2. Write sets are disjoint. Treat a shared public interface, migration sequence, generated artifact, lockfile, formatter target, or test fixture as overlap even when filenames differ.
3. Each worker has isolated mutable resources and an enforced write boundary. Read-only workers may share a worktree; edit workers must not share build outputs, ports, databases, generated files, the Git index, or writable filesystem scope.
4. Every worker starts from a reproducible baseline that contains all required inputs.
5. Codex has a deterministic one-at-a-time integration order, a clean or recoverably snapshotted integration worktree, and a cross-wave verification command.

If any dependency, owner, or baseline is unclear, keep the affected items serial. Do not use parallel workers merely because files appear different.

#### Worktree and dirty-baseline policy

Choose isolation deliberately:

| Situation | Safe choice |
| --- | --- |
| Read-only audits | Workers may share the same worktree; no worker may edit or run mutating Git/build commands. |
| Edits based only on a clean committed SHA | Use one detached or task branch worktree per worker. Each worktree naturally isolates Git index and build output. |
| Edits require current uncommitted or untracked changes | Do **not** assume a new worktree contains them. Without a validated recovery snapshot, run Claude analysis-only and let Codex apply controlled edits; the safe edit-worker count is zero. Edit workers require user authorization for a temporary local snapshot commit or an existing validated, reversible dirty-baseline snapshot mechanism. |
| Same-worktree edits without worktrees | Allowed only when the worktree is clean or recoverably snapshotted, write sets are exact and disjoint, and workers run no build, formatter, generator, package manager, or Git mutation; Codex runs verification serially afterward. Prefer worktrees. |

Serial execution is not a backup. Never give an `acceptEdits` worker a dirty worktree whose prior state cannot be recovered. Never silently stash, commit, copy, or drop user changes to manufacture a baseline. If a temporary snapshot commit is authorized, keep it local, name it in the plan, never push it, and remove it only after all accepted work is safely integrated.

A valid dirty-state recovery record must preserve both tracked changes and required untracked file contents, not merely filenames from `git status`. Record its location, creation method, scope, checksum or base reference, restoration check, and cleanup owner in the resource ledger. If the project has no already-validated mechanism, stop edit delegation and ask for snapshot authority; do not improvise an untested patch/archive procedure on user data.

For every worktree, record its exact path, branch or detached SHA, worker PID/session, owned resources, and cleanup state. Before dispatch, inspect `git worktree list --porcelain` and the source worktree's tracked, staged, and untracked changes. Use explicit paths; never create or remove a broad directory target.

A Git worktree isolates its index and normal build output, not filesystem access. Parallel edit workers additionally require a verified path-qualified `Edit`/`Write` permission boundary or an OS/container sandbox that prevents writes outside that worker's owned worktree paths. Test the boundary before the wave. If the installed Claude version cannot enforce it, run edit workers serially; parallel read-only workers remain allowed. Post-hoc diff review is not a substitute because a worker can otherwise write into a sibling worktree and misattribute the change.

#### Parallel integration and review gate

When a wave finishes:

1. Stop dispatching the next wave.
2. Revalidate the integration worktree's recorded HEAD plus staged, unstaged, and untracked state. It must still be clean or match its verified recovery record; otherwise stop before applying results or running mutating verification.
3. Review each worker's worktree diff independently and rerun its focused verification.
4. Reject out-of-scope edits before integration.
5. Integrate accepted results **one at a time** in the planned order; after each integration, check for semantic/API conflicts with remaining results.
6. Run the cross-wave test/build on the integration worktree. Per-worker green tests are not evidence that the combined result is green.
7. Only then mark the wave `Done` and dispatch dependent items.

If overlap appears after dispatch, interrupt the affected workers at a safe boundary, preserve their worktrees, and serialize those items. Do not race two repair prompts against the same files.

#### Worktree cleanup gate

After integration, inspect every temporary worktree for staged, unstaged, untracked, conflict, and running-process state. Remove a worktree only when its accepted changes are integrated or intentionally rejected and its state is clean. Do not force-remove worktrees to hide unreviewed work. Run `git worktree prune` only after explicit removals. If cleanup is unsafe, preserve the worktree and report its path and recovery command.

### Continuous Queue Mode

Use this mode when the user explicitly asks for continuous tasks, a task queue, or wording like "1-10 tasks, review each one, then automatically start the next."

Continuous queue mode means **review-gated automation**. It is serial by default; independent `Ready` items may run as one Parallel Wave, never as unattended free-for-all execution:

1. Create or update a bounded queue in the target project's planning files. Use an existing `task_plan.md` table when possible; add a `dispatch_queue.md` only when the queue needs extra detail.
2. Each queue item must be a bounded implementation slice with:
   - task ID and status
   - allowed files or directories
   - forbidden changes
   - acceptance criteria
   - verification commands
   - rollback point
3. Select the first eligible serial item, or the first bounded set of `Ready` items that passes the Parallel Wave gate. Mark every dispatched item `In Progress` before starting it.
4. After each Claude worker finishes, independently review its diff and run verification. For a parallel wave, integrate accepted results one at a time and run cross-wave verification before changing any item to `Done`.
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

Keep the invariant: at most one worker owns a queue item, no two workers own overlapping resources, and the active process count never exceeds the recorded wave cap.

Do not stop the queue merely because the next item touches runtime code. Runtime implementation is the point of this mode. Stop only when the scope, invariants, or verification are not clear enough for Codex to review safely.

### Cost-Aware Worker Model

When Claude Code is already configured with DeepSeek or another lower-cost model, prefer using that configured model for implementation, cleanup, and documentation work. The model is only the worker; Codex must still inspect the diff, run verification, and decide whether the result is acceptable.

Do not turn this skill into a model-setup guide. If the configured model is unavailable, fall back to the local Claude Code default or ask the user to fix Claude Code's model configuration.

### 2. Preflight

Run lightweight checks before dispatch:

```bash
pwd
git rev-parse --show-toplevel
git rev-parse HEAD
git branch --show-current
git status --short
git worktree list --porcelain
command -v claude && claude --version
```

Also inspect existing Claude processes/sessions and the task resource ledger. Do not start a duplicate worker for an item already running. Before any `acceptEdits` worker, require a clean target worktree or a verified recovery record for every staged, unstaged, and untracked input it could affect. Before a parallel edit wave, verify path-qualified file permissions or OS sandboxing with two disposable task-owned probe directories: allow one, deny its sibling, confirm the sibling write fails, then remove both probes. Never test the boundary against a real repository, worktree, or user path. Verify the integration worktree baseline, worker worktree paths, build outputs, ports, databases, and available CPU/memory; if any are shared or unknown, reduce the wave or run serially. If the only available baseline is dirty and unrecoverable, use analysis-only workers instead of edit workers.

### 3. Choose Task Size and Wait Policy

Use the task size to decide how long to wait before polling:

| Size | Examples | First wait |
| --- | --- | --- |
| Small | single helper, docs update, focused lint fix | 1-2 minutes |
| Medium | one business chain, 3-8 files, focused component slimming, build/test expected | 5 minutes |
| Large | broad but bounded refactor slice, 8-15 files, meaningful line-count/coupling reduction, build plus docs | 10-15 minutes |

After the first wait, poll every 2-5 minutes depending on expected runtime. Do not emit frequent progress messages unless the user asks for status.

When the user is explicitly conserving Codex tokens, prefer dispatching medium/large slices and sleeping longer over running many Codex-side inspections between tiny worker tasks.

### 4. Build the Dispatch Prompt

The prompt must be explicit and self-contained. Include:

- Worker ID, wave number, task dependencies, workspace/worktree path, branch or detached base SHA.
- Exact task name and goal.
- Plan reference when using `planning-with-files`: file path, task ID, and the specific section Claude should follow.
- Hard constraints: no push/commit/reset, no UI/interaction change unless requested, do not touch build artifacts, preserve existing user changes.
- Allowed scope and files/directories.
- Expected comments/documentation requirements.
- Verification commands.
- Owned mutable resources: build output, ports, databases, temp paths, generated files, and whether verification may run concurrently.
- Required final output: changed files, verification result, risks, next steps, and resource/process state.

Use this command shape for non-interactive dispatch:

```bash
claude -p --permission-mode acceptEdits \
  --allowedTools \
    '<path-qualified Read rule for this worktree>' \
    '<path-qualified Edit rule for exact owned paths>' \
    '<path-qualified Write rule for exact owned paths>' \
    '<path-qualified Glob/Grep rules for this worktree>' \
    '<exact task-specific Bash verification command 1>' \
    '<exact task-specific Bash verification command 2>' \
  --disallowedTools \
    'Bash(git push *)' 'Bash(git commit *)' 'Bash(git reset *)' \
    'Bash(git checkout *)' 'Bash(git switch *)' 'Bash(git restore *)' \
    'Bash(git clean *)' 'Bash(git stash *)' 'Bash(git worktree *)' \
    'Bash(git rebase *)' 'Bash(git merge *)' 'Bash(git cherry-pick *)' \
    'Bash(git revert *)' 'Bash(git apply *)' 'Bash(git am *)' 'Bash(git rm *)' \
    'Bash(rm *)' 'Bash(mv *)' 'Bash(sudo *)' \
  --effort high <<'PROMPT'
...task prompt...
PROMPT
```

Do not grant generic `Bash` to a non-interactive worker. Build the Bash allowlist from the exact verification commands in the plan, without wildcards, shell separators, redirections, command substitution, interpreters, or wrapper commands. Commands such as `python -c`, `perl`, `find`, `sed -i`, `sh -c`, and arbitrary package scripts are not verification allowlist entries. If a verification command cannot be expressed safely, Codex runs it after the worker exits.

The destructive-operation deny list is defense in depth, not a filesystem sandbox: `Edit` and `Write` can still replace content inside their permitted scope. The primary recovery boundary is a clean isolated worktree or a verified dirty-state snapshot. Parallel edit waves require tested path-qualified file rules or OS/container isolation. A clean worktree plus later diff review is insufficient when a worker can reach sibling paths. If enforcement is unavailable, use one edit worker at a time.

These are minimum destructive-operation blocks, not optional examples. Add more `--disallowedTools` entries for task-specific hazards, such as deploy commands, package publication, database mutation, or external messaging. Worktree creation/removal and integration belong to Codex, never to a worker. If the task only needs analysis or the dirty baseline is unrecoverable, use `--permission-mode default`, omit `Edit`/`Write`, and allow only read tools.

For implementation/refactor tasks, use `acceptEdits` so Claude can actually modify files. Avoid accidental "analysis-only" dispatches when the user expects forward progress.

### 5. Wait Efficiently

Let the Claude process run. In Codex Desktop, use the running session and wait according to the size policy. For medium tasks, a 5-minute wait is preferred over repeated short polling when the user wants to save tokens.

For a parallel wave, keep a session table keyed by worker ID. Wait or poll sessions in round-robin with the same size-based cadence; do not start extra workers merely because one is quiet. A completed worker stays in `Review` while the other wave members finish, unless early review can occur without touching their worktrees or shared resources.

If the process exits with no useful output, inspect `git status --short` and recent diffs before deciding whether it failed.

### 6. Independent Review

After Claude finishes:

1. Read Claude's final summary.
2. Inspect changed files in that worker's recorded worktree:

```bash
git status --short
git diff --stat
git diff -- <relevant files>
```

3. Run or repeat focused verification independently in the same isolated worktree. Use the project's known commands, not only Claude's claims.
4. Before verification, record whether every known build artifact path is clean and capture its baseline identity. Restore a generated side effect only when that path was clean before verification, the change is fully attributable to the just-run command, and recovery is available. If the path already contained user changes or attribution is uncertain, preserve it and report the diff; never run a blind `git restore`.

5. If Claude added review helpers or sample runners, execute them if practical. If direct execution needs transpilation, use a temporary in-memory script rather than adding project files unless the task asks for test infrastructure.
6. For a parallel wave, integrate accepted worker results one at a time, then run the recorded cross-wave verification on the integration worktree before marking the wave complete.

Review with findings first:

- Blocking runtime or logic bugs.
- Verification gaps or false documentation.
- Over-broad edits, artifact churn, or changed UI/interaction.
- Missing comments where the user explicitly requested detailed comments.
- Mismatch with the planning file's old-logic chain, branch conditions, or acceptance criteria.

Use managerial judgment during review:

- Patch small mechanical issues directly when that is faster and safer than another worker round.
- Send Claude a focused repair prompt for broader logic mistakes, missed files, incomplete extraction, or false documentation.
- Reject progress that only adds documents while the task was supposed to reduce runtime coupling.
- For slimming work, check whether the large file actually got smaller and whether the extracted file owns a coherent business chain.

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
| Order | Wave | Task ID | Depends On | Goal | Write Scope | Worktree / Base | Owned Resources | Verification | Status | Notes |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | T01 | none | <bounded slice> | <exact files> | <path / SHA> | <build/port/db> | <focused command> | Not Started | <rollback/P0> |
| 2 | 1 | T02 | none | <independent slice> | <exact files> | <path / SHA> | <build/port/db> | <focused command> | Not Started | <rollback/P0> |
| 3 | 2 | T03 | T01,T02 | <integration slice> | <exact files> | <integration path> | <resources> | <cross-wave command> | Not Started | <rollback/P0> |
```

Dispatch cycle:

```text
select next Ready serial item or bounded Ready wave
run dependency/write-set/resource/baseline gate
mark selected items In Progress
dispatch one Claude worker per selected item
wait by task size and track every session
mark completed workers Review
inspect each worktree diff + focused verification
integrate accepted results one at a time
run cross-wave verification
if pass: mark wave Done and continue
if fail: mark affected item Fixing and send one focused repair prompt
if overlap, unsafe cleanup, or repeated failure: mark Blocked and stop queue
```

## Dispatch Prompt Template

```text
Workspace:
<absolute worktree path>

Current branch:
<branch>

Worker / wave / dependencies:
<worker ID> / <wave number> / <depends_on IDs>

Base SHA and isolation:
<base SHA, dirty-baseline strategy, owned build output/ports/database/temp paths>

Plan reference:
<task_plan.md path / task ID / relevant findings.md section, or "none">

Task:
<WP/name>

Goal:
<one paragraph>

Hard constraints:
1. Do not push or commit.
2. Do not run reset, checkout, switch, restore, clean, stash, worktree, rebase, merge, cherry-pick, revert, apply, am, git rm, file deletion, move, or any destructive Git/filesystem command.
3. Do not change UI/interaction unless explicitly requested.
4. Preserve user changes and unrelated dirty files.
5. Keep the scope to <files/areas>.
6. Add clear comments where historical behavior or compatibility is easy to misunderstand.
7. Record build-artifact baselines before validation; restore only artifacts that were initially clean, fully attributable to validation, and recoverable. Preserve and report anything uncertain.
8. Do not read or modify sibling worker worktrees; do not use another worker's ports, databases, build output, temp paths, or generated files.
9. Modify only the exact allowed write paths. Preserve every pre-existing user hunk; if the recorded baseline is missing or differs, stop without editing.

Implementation:
<concrete steps>

Verification:
<commands>

Final output:
- Changed files
- Verification results
- Logic risks found
- Remaining work
- Running processes and owned resources left behind
```

## Final Response to User

After reviewing Claude's work, tell the user:

- Whether Claude's result passed review.
- What changed.
- What you independently verified.
- Any issues you fixed or asked Claude to fix.
- For a parallel wave: which workers ran, their task/worktree ownership, integration order, and cross-wave verification result.
- Which worker sessions, processes, ports, temp paths, and worktrees were removed or intentionally preserved.
- What remains unfinished.

Do not present Claude's summary as fact unless Codex has checked it.
