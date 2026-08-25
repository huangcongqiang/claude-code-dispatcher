# Bounded waves and non-LoopX queues

Read this reference only when the request explicitly needs multiple workers, a finite wave, or continuous non-LoopX execution.

## Mode selection

- Default: one worker for one frozen task.
- Bounded wave: two or more independently reviewable ready tasks with proven disjoint ownership.
- Continuous queue: explicitly requested, no LoopX lifecycle owner, and persisted through `planning-with-files`.

When LoopX is connected, do not use this queue. Execute only the one frozen todo selected upstream.

## Parallel-wave gate

Default wave size is 2. Increase up to 4 only after checking host agent/process capacity, CPU, memory, write sets, build outputs, ports, databases, generated files, and integration capacity. A larger wave requires explicit direction.

Every task row records task/worker ID, dependencies, wave, exact write scope, shared interfaces/schemas/migrations, worktree/base, mutable-resource ownership, validation, and integration order.

All gates must pass:

1. no task consumes another task's unintegrated output;
2. write sets are disjoint, including public interfaces, migration order, generated artifacts, lockfiles, formatter targets, and fixtures;
3. mutable resources and filesystem boundaries are isolated;
4. every worker starts from a reproducible baseline containing its required inputs;
5. the primary agent has a deterministic serial integration order and cross-wave verification.

Different filenames do not prove independence. If any dependency, owner, or baseline is unclear, serialize.

## Continuous queue

Use the existing `planning-with-files` task table when possible; create no competing queue artifact unless extra detail is genuinely necessary. Each item has one owner and one of:

- `Not Started`
- `In Progress`
- `Review`
- `Fixing`
- `Done`
- `Blocked`
- `Skipped`

The primary agent selects one eligible item or one bounded safe wave, records dispatch before launch, reviews actual diffs, integrates serially, verifies the combined result, and only then changes status. One repair worker may receive a focused retry; do not race repairs against the same files.

Stop the queue when it is empty, an item is blocked, the same item fails after 2-3 focused attempts, scope is violated, validation needs user/external authority, the next item lacks a frozen contract, cleanup is unsafe, or the user changes direction.

Continuous means review-gated continuation, not unattended free-for-all execution. Runtime code is allowed when it is the frozen objective; documentation-only motion is not progress toward a requested implementation.
