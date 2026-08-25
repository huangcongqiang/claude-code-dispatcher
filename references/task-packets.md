# Claude dispatch packet

Read this reference when composing an implementation or repair prompt. Copy upstream frozen identities and contracts verbatim.

```text
Protocol:
delivery-governance@1.0.0 / <local SHA-256>

Goal / program / task / packet:
<IDs, packet version, dependencies, observable acceptance result>

plan_owner:
<planning-with-files paths and plan/task IDs, authoritative equivalent, or none>

lifecycle_owner:
<LoopX goal/todo, planning phase/task, or current task>

status_projection:
<LoopX verified readback -> planning milestone, or none>

writeback_owner:
<upstream manager/delivery loop, standalone dispatcher, or primary agent>

implementation_fact_owner:
<repo/worktree, immutable baseline, dirty fingerprint, evidence paths>

contract_owner:
<architecture ID/version; Ponytail ID/version; review ID/version>

Workspace and resources:
<actual process cwd; branch/detached SHA; isolation; build/port/db/temp/generated ownership>

Authoritative references:
<requirements, source chain, API/schema/data, Figma/screenshot/demo paths>

Objective:
<one bounded implementation result>

Architecture contract:
<bounded context; one-way flow; state owner; invariants/transitions; effects/ports; failure exits; dependency direction; authorization/idempotency/concurrency; compatibility/migration/rollback; or why extra DDD structure is not applicable>

Ponytail solution contract:
<frozen intensity, first sufficient rung, reuse evidence, non-goals, ceiling/upgrade trigger, minimal runnable regression check>

Review contract:
<normal/exception/boundary scenarios; architecture/scope/security checks; required evidence/commands; P0/P1/P2 gate; rollback; cleanup>

Allowed and expected paths:
<exact paths/globs>

Forbidden paths and actions:
<exact paths; no commit/push/deploy/destructive Git; no sibling worktree/resource access>

Role and change control:
The primary agent owns requirements, architecture, contracts, findings, integration, verification, and acceptance. Claude implements and self-checks only. On evidence conflicting with a frozen contract or baseline, stop and report it under DG-08; do not broaden scope or lower criteria.

Implementation:
<concrete task instructions, preserving existing user hunks>

Verification:
<exact safe worker commands; commands reserved for the primary agent>

Stop conditions:
<baseline mismatch, permission denial, conflicting facts, scope need, unsafe resource, missing authority>

Final output:
- actual changed paths
- commands and results
- unresolved risks or contract conflicts
- running processes and owned resources
- exact next safe action
```

For a repair prompt, keep the same protocol, owner identities, baseline, scope, and contract versions. Add exact file/line findings, the required correction, forbidden changes, and checks to rerun. If the correction changes acceptance or architecture, refreeze upstream instead of issuing a repair.
