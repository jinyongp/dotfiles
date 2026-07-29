# Workstream Spec-Kit Improvements Plan

## Goal

Improve the `workstream` skill with proportional specification, traceability,
artifact analysis, and convergence while preserving its stronger execution,
verification, review, and closeout contracts.

## Artifact Depth

- Standard: material user-visible agent-orchestration behavior with multiple
  acceptance paths. Reuse the existing user request and completed source
  analysis instead of creating a duplicate `spec.md`.

## Intent Source

- User request to improve `$workstream` from the completed github/spec-kit
  analysis at inspected commit `3f7392ae32131c9cfe6a1f97c5c213311183263a`.
- Existing `agents/skills/workstream/SKILL.md` contracts and user-owned edits.

## Scope

- Update `agents/skills/workstream/SKILL.md`.
- Add focused `agents/skills/workstream/references/` files for conditional goal
  continuity and artifact-template loading.
- Update `agents/skills/workstream/agents/openai.yaml` only if its UI metadata
  no longer describes the revised workflow.
- Preserve existing user changes in `workstream`, `planning`, and `review-loop`.

## Non-goals

- Do not copy Spec Kit's CLI, template hierarchy, hook system, branch creation,
  or feature-directory machinery.
- Do not weaken mandatory verification, review-loop, or closeout.
- Do not modify `planning`, `queue`, `taskwarrior`, `verify`, `review-loop`, or
  `close` in this workstream.
- Do not stage or commit changes.

## Requirements

- REQ-001: Workstream must choose proportionate intent artifacts instead of
  requiring full specification ceremony for every change.
- REQ-002: Workstream must trace requirements and acceptance criteria through
  implementation work and validation.
- REQ-003: Workstream must detect cross-artifact coverage and consistency gaps
  before execution.
- REQ-004: Workstream must compare the implemented result with intent and
  re-enter execution for evidence-backed gaps.
- REQ-005: Workstream must preserve mandatory verification, review-loop,
  closeout, Taskwarrior state, user-work protection, and opt-in commits.

## Acceptance Criteria

- AC-001 (REQ-001): Light, standard, and high-risk artifact depths have explicit
  selection rules and existing authoritative specs can be reused.
- AC-002 (REQ-002): `REQ-###`, `AC-###`, `WI-###`, and `VAL-###` mappings are
  defined in both workflow rules and plan format.
- AC-003 (REQ-003): A read-only pre-queue analysis checks ambiguity,
  contradiction, governance, coverage, ordering, paths, and terminology.
- AC-004 (REQ-004): Convergence classifies gaps, appends new work without
  rewriting history, and has a bounded blocker rule for repeated failures.
- AC-005 (REQ-005): Existing execution, validation, review, closeout, safety,
  goal continuity, and nested review delegation contracts remain present.

## Constraints

- Caveman response mode remains active until the user disables it.
- Keep `SKILL.md` concise and below the skill-creator 500-line guidance.
- Use proportionate artifacts: small maintenance work must not require a full
  product specification.
- Keep unresolved decisions in conversation; persist only settled intent.
- Keep Taskwarrior repo-local and retain its authority for execution state.
- Preserve unrelated dirty-worktree changes.
- Validation must include skill-creator `quick_validate.py`, focused textual
  contract checks, and the required planning-axis review-loop.

## Governance Check

- PASS: `AGENTS.md` rules loaded; shell commands followed repository rules and
  manual edits use `apply_patch`.
- PASS: Existing dirty changes identified; only current-session workstream files
  and the new plan are in implementation scope.
- PASS: Skill remains below 500 lines and keeps detailed behavior in its existing
  delegated skills rather than duplicating them.
- PASS: No branch, stage, commit, repository dependency install, or destructive operation.

## Assumptions

- Existing AGENTS/repository rules are the governance source; a separate
  constitution file is optional, not mandatory.
- Stable IDs can use `REQ-###`, `AC-###`, `WI-###`, and `VAL-###` without adding
  scripts or a new persisted schema.
- A phase ledger belongs in the plan document and complements Taskwarrior rather
  than replacing it.

## Work Items

- WI-001 (REQ-001, AC-001) Define a proportional `specify/clarify` intake contract and stable intent IDs.
- WI-002 (REQ-003, AC-003) Add governance and read-only cross-artifact analysis gates before queueing.
- WI-003 (REQ-002, REQ-004, AC-002, AC-004) Add traceable Taskwarrior mapping, phase ledger, and implement/verify/converge re-entry loop.
- WI-004 (REQ-005, AC-005) Preserve and tighten review-loop, closeout, safety, and explicit non-adoption rules.
- WI-005 (REQ-005, AC-005) Refresh `agents/openai.yaml` if its description is stale.

## Validation

- VAL-001 [standalone] (WI-001..WI-005, AC-001..AC-005) Run skill-creator `quick_validate.py` on the workstream skill.
- VAL-002 [standalone] (WI-001..WI-005, AC-001..AC-005) Check required phases, traceability IDs, convergence behavior, line count, and preserved safety contracts.
- VAL-003 [review] (WI-001..WI-005, AC-001..AC-005) Run the required planning-axis review-loop until no actionable findings remain.

## Phase Ledger

| Phase | Status | Evidence | Next |
|---|---|---|---|
| Intake | complete | Goal, scope, prior spec-kit analysis, dirty-worktree check | Plan |
| Plan | complete | This document with traceable requirements and validation | Analyze |
| Analyze | complete | Coverage map AC-001..AC-005 to WI/VAL; no open decision | Queue |
| Queue | complete | Eight repo-local Taskwarrior tasks with strict dependencies | Execute |
| Execute | complete | Workstream skill and UI metadata updated | Verify |
| Verify | complete | quick_validate and diff check pass; SKILL 321 lines; direct references 133; metadata 7; required contracts found | Converge |
| Converge | complete | AC-001..AC-005 mapped; lifecycle/re-entry/scope guards added; no remaining intent gap | Review |
| Review | complete | Four cycles; planning contract, forward-test, minimality; no actionable findings | Close |
| Close | complete | 8/8 tasks; validation pass; review clean; mixed dirty tree identified; no commit | End |

## Risks

- Added ceremony could make small workstreams inefficient; mitigate with an
  explicit artifact-depth decision.
- Duplicate responsibility across planning, verify, and review-loop could drift;
  keep workstream as orchestration and delegate detailed behavior.
- Convergence could become unbounded; require evidence-backed gaps, append-only
  tasks, and a bounded re-entry rule for repeated root causes.
