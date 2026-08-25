# Claude CLI execution

Read this reference when dispatching or recovering a Claude CLI process.

## Preflight

From the exact target workspace, inspect:

```bash
pwd
git rev-parse --show-toplevel
git rev-parse HEAD
git branch --show-current
git status --short
git worktree list --porcelain
command -v claude
claude --version
```

Also inspect existing Claude processes/sessions and the task resource ledger. Do not launch a second process for an item that may still be running.

Claude may already be configured to use DeepSeek or another model. Use the current persistent CLI configuration; do not read, expose, or modify model credentials or settings through this skill. If the required backend is unavailable, let the primary agent implement within the existing authority or report the blocker. Do not silently replace the requested backend.

## Enforced working directory and baseline

Start the process with its actual process working directory set to the frozen workspace; a path written only in the prompt is not enforcement. Before editing, require readback of `pwd`, repository root, and `HEAD` or the packet's explicit non-Git baseline. Stop on any mismatch.

Use `acceptEdits` only for an authorized edit task with a clean isolated worktree or a verified recovery snapshot. For analysis-only work, use the default permission mode and omit Edit/Write permissions.

## Non-interactive command shape

```bash
claude -p --permission-mode acceptEdits \
  --allowedTools \
    '<path-qualified Read rule for this worktree>' \
    '<path-qualified Edit rule for exact owned paths>' \
    '<path-qualified Write rule for exact owned paths>' \
    '<path-qualified Glob/Grep rules for this worktree>' \
    '<exact task-specific verification command>' \
  --disallowedTools \
    'Bash(git push *)' 'Bash(git commit *)' 'Bash(git reset *)' \
    'Bash(git checkout *)' 'Bash(git switch *)' 'Bash(git restore *)' \
    'Bash(git clean *)' 'Bash(git stash *)' 'Bash(git worktree *)' \
    'Bash(git rebase *)' 'Bash(git merge *)' 'Bash(git cherry-pick *)' \
    'Bash(git revert *)' 'Bash(git apply *)' 'Bash(git am *)' \
    'Bash(git rm *)' 'Bash(rm *)' 'Bash(mv *)' 'Bash(sudo *)' \
  --effort high <<'PROMPT'
<frozen task packet>
PROMPT
```

Do not grant generic Bash. Allow only exact verification commands from the task packet, without wildcards, shell separators, redirection, command substitution, interpreters, or wrapper commands. Commands such as `sh -c`, `python -c`, `perl`, `find`, `sed -i`, and arbitrary package scripts are not safe verification allowlist entries. The primary agent runs commands that cannot be expressed narrowly.

The deny list is defense in depth, not a filesystem sandbox. Add task-specific deploy, publication, database-mutation, or messaging commands to it. Worktree creation, integration, cleanup, commit, push, and deployment remain outside the worker.

## Waiting and recovery

Use expected task size for the first wait:

| Size | Typical slice | First wait |
| --- | --- | --- |
| Small | one helper, documentation, focused lint fix | 1-2 minutes |
| Medium | one business chain, 3-8 files, build/test | about 5 minutes |
| Large | bounded refactor, 8-15 files, build plus evidence | 10-15 minutes |

Afterward poll every 2-5 minutes. A quiet process is not proof of failure. After two unchanged checks, inspect the recorded session/process and workspace before interrupting or retrying.

If the process exits without useful output, inspect actual status and diff first. If it is still live, keep its identity and wait or interrupt only under the recorded stalled-worker condition. If it exited with a diff, continue at diff inspection. If it exited without a diff, use the caller's empty-diff recovery; never redispatch merely because the terminal output was lost.
