---
protocol_id: delivery-governance
version: 1.0.0
---

# Delivery Governance

This vendored protocol keeps standalone dispatcher, delivery-loop, and engineering-manager skills consistent. The local skill decides execution mechanics; this file defines ownership, decomposition, contracts, acceptance, persistence, and recovery.

## Invariants

- **DG-01 — Requirement authority:** User decisions and named authoritative artifacts define the requested outcome. The primary agent resolves conflicts, records unknowns, and freezes the accepted interpretation.
- **DG-02 — Overall-plan owner:** For a broad or complex goal, `planning-with-files` owns the overall roadmap, architecture decisions, findings, and execution evidence. A bounded task may reuse an existing authoritative plan instead of creating ceremonial planning files.
- **DG-03 — Lifecycle owner:** When LoopX is connected and authorized, its goal and todos are the only durable owner of current/next task state. Without LoopX, `planning-with-files` owns phase/task status. The highest active workflow that selected or claimed the task is the only writeback actor; nested skills return evidence upstream. Never maintain two writable queues or two lifecycle writers.
- **DG-04 — Implementation-fact owner:** Repository/worktree contents, immutable baseline, actual diff, tests, builds, runtime observations, and external readback are the authority for what happened. Chat and worker summaries are not proof.
- **DG-05 — Contract owner:** The latest frozen, versioned task packet owns architecture, solution, review, scope, and verification criteria for the current slice. A worker or reviewer cannot silently rewrite it.
- **DG-06 — Role separation:** The primary agent owns architecture, scope, prioritization, finding adjudication, integration, verification, cleanup, and final acceptance. An implementation worker edits only the frozen slice. Reviewers are read-only and cannot accept their own or another worker's work.
- **DG-07 — One-way projection:** Under LoopX, the lifecycle-owning workflow writes transitions to LoopX, reads back the exact goal/todo, and only then projects the verified milestone into planning files. Planning files never dispatch from stale projected status.
- **DG-08 — Refreeze on conflict:** If source facts invalidate a frozen requirement, architecture, Ponytail, review, or scope contract, stop implementation. The primary agent versions and refreezes the affected contract before execution resumes.
- **DG-09 — Clean acceptance gate:** Acceptance requires an inspected in-scope diff or proven no-change result, zero known P0/P1/P2 findings in the latest full review, required validation, truthful writeback, and verified resource cleanup.
- **DG-10 — Authority boundary:** No skill, worker, reviewer, plan, or lifecycle tool expands authorization. Commit, push, deployment, deletion, credential use, external writes, or destructive recovery require the authority already present in the user request and host rules.

## Execution shape

Choose the narrowest layer that owns the requested outcome:

- trivial or tightly coupled change: primary agent implements directly and retains verification;
- one bounded worker task: dispatcher;
- one non-trivial delivery slice: delivery loop;
- explicit LoopX-backed, long-running, multi-task program: engineering manager;
- finite independent tasks: an explicitly bounded dispatcher wave only when write sets, resources, and integration order are proven safe.

Do not activate a program queue merely because implementation needs several commands. Do not use a dispatcher as an architecture or acceptance owner.

## Planning and rolling-wave decomposition

For a broad goal:

1. establish facts, unknowns, constraints, observable completion, and authoritative sources;
2. create or refresh the `planning-with-files` overall roadmap;
3. freeze only the minimum program architecture needed to keep later slices consistent;
4. keep future modules/slices coarse and fully detail only the next eligible slice;
5. when LoopX is used, import or link the executable frontier into LoopX without transferring overall-plan ownership;
6. after verified delivery, update LoopX first, read it back, then update planning milestones, findings, decisions, and evidence.

Split a slice when it crosses independent state owners, transaction/effect boundaries, sources of truth, acceptance decisions, conflicting write sets, or cannot reasonably complete in one bounded worker session. Do not split by fictional personas or technical layers alone.

## Architecture and solution contracts

Use progressive DDD only when business rules, state transitions, or external effects justify it. Keep simple CRUD, presentation-only work, and local utilities simpler.

The default one-way flow is:

`Delivery/UI/API → Command → UseCase → Domain Decision → Effect Plan → Port/Adapter → Result → Domain Transition → State Owner → Projection`

The architecture contract records only applicable items: bounded context, one state owner per business fact, invariants, legal transitions, dependency direction, effects and ports, failure exits, authorization, idempotency, concurrency, compatibility, migration, rollback, and old-owner deletion gate.

After tracing the affected flow, apply Ponytail to choose the first sufficient implementation rung. Ponytail reduces solution size; it never reduces required understanding, explicit behavior, architecture correctness, security, data integrity, recovery, rollback, accessibility, or verification.

## Mandatory task-packet identity

Every delegated implementation or review packet must identify:

- `protocol`: `delivery-governance@1.0.0` and the local protocol SHA-256 when available;
- goal/program/task ID, packet ID/version, dependencies, and observable acceptance result;
- `plan_owner` and exact plan/findings/progress references, or `none`;
- `lifecycle_owner`: exact LoopX goal/todo, planning phase/task, or current task;
- `status_projection`: for example `LoopX readback → planning milestone`, or `none`;
- `writeback_owner`: the manager, delivery loop, standalone dispatcher, or primary agent that alone may mutate lifecycle/status;
- `implementation_fact_owner`: repository/worktree, immutable baseline, dirty fingerprint, and evidence paths;
- `contract_owner`: architecture, Ponytail, and review contract IDs/versions;
- exact working directory, allowed paths, expected paths, forbidden paths/actions, resource ownership, and isolation strategy;
- authoritative requirement, API, schema, data, Figma, screenshot, and demo references that apply;
- required commands, observable evidence, severity gate, rollback, cleanup, and stop conditions;
- role boundaries and the DG-08 refreeze rule.

Child skills copy upstream identity and frozen contracts verbatim. They may add execution evidence, never create competing owner or contract identities.

## Review and acceptance contract

Freeze review criteria before implementation. Cover the task-specific normal, exception, and boundary scenarios; architecture/state invariants; security and failure behavior when applicable; allowed and forbidden scope; required evidence and commands; rollback; cleanup; and the P0/P1/P2 gate.

Give reviewers the same frozen contracts plus raw source, actual diff, and verification evidence. Do not prime them with the worker's conclusion or prior reviewer findings. A newly discovered material risk may reopen the task, but it cannot silently become a post-hoc acceptance rule: the primary agent must version and refreeze the contract.

The primary agent verifies every finding against source, fixes the root cause with the smallest in-scope change, reruns affected checks, and finishes with one full review of the latest candidate.

## Writeback and recovery order

At durable boundaries record compact, public-safe evidence: baseline established, lifecycle claim read back, worker dispatched, diff captured, integration verified, lifecycle writeback read back, and cleanup verified.

On interruption, compaction, duplicated tool output, or an ambiguous worker result:

1. stop new dispatch, integration, and lifecycle mutations;
2. reload the planning references, lifecycle identity, task packet, repository/worktree, worker identity, actual diff, and last validation evidence;
3. continue from the last uniquely proven durable boundary;
4. never redispatch solely because chat context or a wait result was lost;
5. fail closed when identity, ownership, baseline, integration, or writeback remains ambiguous.

A nested dispatcher or delivery loop returns a compact evidence/writeback packet to its upstream owner and does not mutate the same lifecycle or planning status. When the current workflow is the declared `writeback_owner`: without LoopX, update `planning-with-files` status and evidence after verified integration; with LoopX, update and read back LoopX first, then project the milestone and preserve detailed findings/evidence in planning files.

## Protocol alignment

All six supported skill repositories vendor this file. Copies with the same version must be byte-identical. A protocol change requires updating all copies, the task-packet fields, relevant skill routing, and the alignment check in one reviewed change.

Run `ruby scripts/check_protocol_alignment.rb` for a standalone repository. When all six sibling repositories are installed under one root, run:

```bash
ruby scripts/check_protocol_alignment.rb --siblings-root /path/to/skills --require-all
```
