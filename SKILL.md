---
name: claude-code-dispatcher
description: Delegate bounded terminal implementation, cleanup, analysis, or explicitly safe finite-wave work to Claude Code while Codex retains planning, architecture, scope, review, integration, verification, and acceptance. Use when the user or host rules require Claude CLI execution, including isolated worktrees or an explicitly requested non-LoopX queue. Do not use as a substitute for the single-task delivery loop or a LoopX program manager.
---

# Claude Code Dispatcher

Use Claude Code as a bounded implementation worker. The primary Codex agent remains the delivery owner.

Default flow:

`frozen packet → verified workspace/baseline → one Claude process → actual diff → primary-agent evidence gate → caller review/acceptance → writeback → cleanup`

## Load the governance contract

Read [references/delivery-governance.md](references/delivery-governance.md) before shaping broad direct work, composing a packet, interacting with `planning-with-files` or LoopX, running a queue/wave, recovering ambiguity, or changing this skill's protocol.

Core ownership remains:

- `planning-with-files` owns the overall roadmap, architecture decisions, findings, and evidence for broad work;
- LoopX, when connected, owns lifecycle state; otherwise planning files may own phase/task status;
- repository/worktree/diff/tests own implementation facts;
- the latest frozen packet owns contracts;
- the primary agent owns architecture, integration, verification, and acceptance;
- Claude implements and self-checks only.

Run `ruby scripts/check_protocol_alignment.rb` after changing governance, packet fields, or routing. With all six sibling skills installed, add `--siblings-root <skills-root> --require-all`.

## Choose the narrowest execution shape

1. **Direct primary-agent work:** trivial, tightly coupled, or judgment-heavy change.
2. **Single dispatch:** default; one frozen bounded task and one Claude process.
3. **Bounded wave:** only when the user/host permits multiple workers and every dependency, write set, mutable resource, baseline, and integration gate is proven independent.
4. **Continuous non-LoopX queue:** only when explicitly requested; `planning-with-files` owns the queue.
5. **Delivery loop:** use `claude-terra-delivery-loop` for one non-trivial task that needs independent review-fix and final integration.
6. **LoopX manager:** use `loopx-engineering-manager` only for an explicitly LoopX-backed, long-running multi-task program.

Read [references/queue-mode.md](references/queue-mode.md) before modes 3 or 4. Default to one worker. A request for speed permits evaluating parallelism; it does not prove safety.

## Freeze planning and contracts before dispatch

If an upstream manager or delivery loop provides a frozen packet, verify its identity and copy it verbatim. Do not create a competing plan, owner, or contract version.

For broad direct work without an upstream packet:

1. inspect the complete affected flow, authoritative artifacts, facts, unknowns, constraints, and observable result;
2. load `planning-with-files` and create or refresh the overall plan unless an authoritative equivalent already exists;
3. freeze the minimum architecture and a coarse module/business-slice map;
4. detail only the next dependency-ready slice;
5. load `ponytail` after architecture is understood, respect an explicit intensity or use `full`, and freeze the first sufficient solution;
6. freeze the review criteria before implementation.

Use progressive DDD only when business rules, state transitions, or external effects justify it:

`Delivery/UI/API → Command → UseCase → Domain Decision → Effect Plan → Port/Adapter → Result → Domain Transition → State Owner → Projection`

Keep CRUD, presentation-only work, and local utilities simpler. The dispatcher does not invent tactical DDD files or choose program architecture.

Every editing packet must have mutually consistent versioned architecture, Ponytail, and review contracts plus the governance ownership fields. Read [references/task-packets.md](references/task-packets.md) when composing implementation or repair prompts. Stop under DG-08 if repository facts conflict with a frozen contract.

## Preflight and isolation

Before dispatch:

1. read applicable `AGENTS.md`, project instructions, task cards, plans, and authoritative references;
2. inspect the actual target path, repository root, immutable revision, branch, staged/unstaged/untracked state, worktrees, existing Claude processes/sessions, and owned resources;
3. prove that the worker's required inputs exist in its workspace;
4. require a clean worktree or a validated recovery record before edit delegation;
5. freeze exact allowed/expected/forbidden paths, verification commands, build outputs, generated files, ports, databases, temp paths, and cleanup owner;
6. verify that no existing process already owns the same task or mutable resource.

Read [references/worktrees.md](references/worktrees.md) for dirty/shared repositories, worktrees, parallel workers, integration, and cleanup. Never silently stash, commit, copy, reset, or drop user changes to manufacture a baseline.

If the target dirty state cannot be recovered safely, dispatch analysis-only or let the primary agent make controlled edits. Do not give an editing process an unrecoverable workspace.

## Start one bounded Claude process

Read [references/claude-cli.md](references/claude-cli.md) for the current CLI preflight, permission contract, command shape, exact-tool allowlist, wait cadence, and process recovery.

The process working directory must equal the frozen workspace. Require it to read back `pwd`, repository root, and immutable baseline before editing. A path present only in the prompt is not enforcement.

Claude may modify runtime code when that is the frozen objective. Do not turn an implementation task into documentation-only output. Do not let Claude:

- commit, push, deploy, publish, delete broadly, mutate worktrees, or run destructive Git;
- access sibling worker worktrees or resources;
- broaden scope, reinterpret architecture, lower review criteria, or change owner identities;
- spawn another worker or delegate the task;
- hide verification side effects or claim acceptance.

Use the CLI's existing persistent model configuration. This skill never reads or changes model keys/settings. If Claude is unavailable, the primary agent may take over within the existing authority or report the blocker; never silently substitute another worker backend.

## Wait and recover by evidence

Wait according to expected task size and keep user updates within host communication rules. A quiet process, lost terminal output, reconnect, or context compaction is not permission to dispatch again.

Before retrying:

1. inspect the recorded process/session identity;
2. inspect the exact workspace, baseline, status, and actual diff;
3. continue from the last proven boundary;
4. interrupt only a proven stalled process;
5. preserve ambiguous work and fail closed rather than duplicate it.

## Inspect the actual result

After Claude exits, independently inspect the recorded workspace before trusting its summary:

```bash
git status --short
git diff --stat
git diff -- <relevant paths>
git diff --check
```

Also inspect expected untracked or explicitly authorized ignored files and compare any recorded digests. Confirm the immutable baseline did not move, changed paths are in scope, requested behavior exists, no unrelated churn was mixed in, and worker-side commands actually ran against the changed workspace.

If there is no diff:

1. determine whether the baseline already satisfies acceptance;
2. verify workspace, revision, permissions, process output, and sibling paths;
3. permit at most one narrowed retry with the exact missing observable or failing assertion;
4. then let the primary agent implement or report a real blocker.

Never perform a fictional review of unchanged code.

## Review, repair, and hand back

When invoked by a delivery loop or manager, return raw diff and verification evidence to that caller; do not declare the outer task accepted.

When used standalone, the primary agent reviews against the frozen contracts, verifies findings from source, and independently runs the required checks. Claude's self-check is not acceptance.

For a bounded repair, reuse the same worker only after it is idle and preserve packet identity, owner fields, baseline, contracts, and scope. Provide exact file/line findings, required correction, forbidden changes, and commands to rerun. If the fix changes architecture or acceptance, refreeze upstream instead.

After 2-3 focused failures on the same issue, stop redispatching. The primary agent either applies a smaller safe fix within scope or reports the blocker.

## Write back and clean up

When a delivery loop or manager invoked this dispatcher, return raw evidence and cleanup state to that upstream `writeback_owner`; do not mutate the same planning or LoopX lifecycle. The following status writeback applies only when this dispatcher is the declared standalone owner and the primary agent has verified the integrated result:

- record actual changed files, commands/results, review/repair rounds, impact, rollback, residual risk, and evidence;
- without LoopX, update `planning-with-files` status and evidence when it owns the task;
- with LoopX, write the lifecycle transition there, read back the exact todo, then project the milestone into planning files;
- stop or account for every Claude process, port, database, temp path, generated artifact, and worktree;
- preserve unsafe-to-remove resources with exact recovery instructions.

Report what Claude changed, what the primary agent independently verified, whether the result passed the applicable gate, any repair performed, and all remaining work/resources. Never present the worker summary as verified fact.
