# Worktree and resource isolation

Read this reference before any edit worker on a dirty/shared repository, or before a parallel wave.

## Isolation choice

| Situation | Safe choice |
| --- | --- |
| Read-only audit | Workers may share a workspace if they run no mutating Git/build command. |
| Edits based on a clean committed SHA | Use one task branch or detached worktree per worker. |
| Edits require uncommitted or untracked inputs | Do not assume a new worktree contains them. Without an already validated recovery snapshot, use analysis-only delegation and let the primary agent apply controlled edits. |
| Same-worktree edits | Allow only with a clean or recoverably snapshotted baseline, exact disjoint writes, no parallel build/generator/package/Git mutation, and serial verification. Prefer worktrees. |

Never silently stash, commit, copy, archive, or drop user changes to manufacture a baseline. A temporary local snapshot commit requires explicit authority, must never be pushed, and remains until accepted work is safely integrated.

A valid dirty-state recovery record preserves required staged, unstaged, and untracked contents, not only filenames. Record scope, method, location, base/checksum, restoration check, and cleanup owner. If no validated mechanism exists, the safe edit-worker count is zero.

## Resource ledger

For each worker record:

- task/worker identity and dependencies;
- exact worktree, branch or detached SHA, immutable baseline, and dirty fingerprint;
- allowed/expected/forbidden paths;
- owned build output, generated files, temp paths, ports, databases/schemas, and caches;
- process/session identity and last observed state;
- integration order, focused validation, cross-wave validation, and cleanup state.

A Git worktree isolates its index and ordinary local output, not general filesystem access. Parallel edit workers require tested path-qualified Edit/Write rules or an OS/container sandbox. Test only with disposable task-owned probe directories. If the boundary cannot be enforced, edit serially.

## Integration gate

When a worker finishes:

1. stop new dependent dispatch;
2. revalidate the integration workspace against its recorded baseline or recovery record;
3. inspect each worker diff and run focused verification in that worktree;
4. reject out-of-scope changes;
5. integrate accepted results one at a time in the frozen order;
6. after each integration, check semantic/API conflicts with remaining candidates;
7. run cross-wave verification on the integrated result.

Per-worker green tests do not prove the combination is correct. If overlap appears, interrupt matching workers at a safe boundary, preserve their worktrees, and serialize the work.

## Cleanup gate

Inspect staged, unstaged, untracked, conflict, process, port, and generated-output state before cleanup. Remove a temporary worktree only after its result is integrated or intentionally rejected and no unique evidence remains. Never force-remove a worktree to hide unreviewed work. If cleanup is unsafe, preserve the exact path and report its recovery action.
