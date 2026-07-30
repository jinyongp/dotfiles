# Workstream Artifact Contracts

Read this file before creating or updating a workstream specification or plan.
Use the repository's established template when it has an equivalent contract;
otherwise use the relevant format below. Repository templates may change
content layout only; they never change resolver identity, paths, or filenames.

## Plan Format

```md
# <Title> Plan

## Goal

## Task Identity
- Slug: <resolver slug>
- Directory: <resolver work_dir_relative>
- Project: <slug>
- Manifest: <resolver manifest_path_relative>

## Artifact Depth
- <Light|Standard|High-risk>: <evidence-based rationale>

## Intent Source
- Kind: <plan-local|authoritative>
- Source: <plan-local or exact path|URL|identifier>

## Scope

## Non-goals

## Requirements
- REQ-001 ...

## Acceptance Criteria
- AC-001 (REQ-001) ...

## Constraints

## Governance Check

## Assumptions

## Work Items
- WI-001 (REQ-001, AC-001) ...

## Validation
- VAL-001 [task-local] (WI-001, AC-001) ...
- VAL-002 [standalone] (WI-001, risk: ...) ...

## Phase Ledger
| Phase | Status | Evidence | Next |
|---|---|---|---|

## Risks
```

Use `pending`, `in_progress`, `complete`, or `blocked` for ledger status. Work
item and validation bullets define contracts; after queueing, Taskwarrior is the
only authority for their completion state. Reconcile the ledger from Taskwarrior
at phase transitions and closeout instead of mirroring task checkboxes.

Use only the fixed filenames and directory returned by
`scripts/resolve_workstream.py`; see `references/path-contract.md` for identity,
reuse, and collision rules.

For light work, keep `Requirements` and `Acceptance Criteria` compact. Omit
empty `Non-goals`, `Assumptions`, and `Risks`; use a compact `Governance Check`
only when task-specific rules apply. Keep Goal, Artifact Depth, Intent Source,
Task Identity, Scope, Requirements, Acceptance Criteria, Constraints, Work
Items, Validation, and Phase Ledger. For standard/high-risk work, place full
detail in `spec.md` and keep concise plan references.

## Specification Format

Use only for standard/high-risk work when no authoritative intent source exists:

```md
# <Title> Specification

## Intent
## User Scenarios
## Requirements
- REQ-001 ...
## Acceptance Criteria
- AC-001 (REQ-001) ...
## Edge and Recovery Cases
## Non-functional Requirements
## Assumptions
## Non-goals
```

## Validation Format

```md
# Validation

## Scope

## Checks
| ID | Kind | Command or Method | Result | Evidence |
|---|---|---|---|---|
| VAL-001 | task-local / standalone | ... | pass / fail / blocked / skipped | ... |

## Accepted Gaps
- None.

## Final Status
- pass|fail|blocked|skipped-with-accepted-risk
```

Keep exact commands and failure reasons. Append a new check row when rerun;
never overwrite earlier evidence to hide a failure.
