---
name: verify
description: >
  Choose and run validation for code, docs, config, UI, API, database, refactor,
  and bugfix work. Use when the user asks to verify, validate, test, confirm,
  check, 검증, 확인, 테스트, or when workstream needs a consistent validation
  matrix before marking tasks done. Produces focused checks, pass/fail criteria,
  and exact skipped or blocked validation gaps.
---

# Verify

Run validation only when it can materially reduce uncertainty about a plausible
failure. If no check adds meaningful signal relative to its cost, report
`not-needed`. Otherwise define the smallest checks that prove the change, then
run what is practical.
Do not edit code unless the user asks or the active workflow already permits
fixes.

## Workflow

1. Classify change
   - bugfix, feature, refactor, UI, API, database, config, docs, dependency, tooling.
   - Multiple types allowed. Validate each material risk.
   - Identify a plausible failure and its impact. No material failure means validation is `not-needed`.

2. Pick checks
   - Prefer repo-local scripts and existing test style.
   - Use targeted checks first, broader checks for shared or risky changes.
   - Tie every check to a work item, behavior, or risk.

3. Run checks
   - State commands before long or risky runs.
   - Do not install dependencies or start long-lived servers unless needed and acceptable.
   - If a command fails, distinguish product failure, test failure, missing dependency, and environment issue.

4. Report result
   - Pass: name checks run.
   - Fail: include failing command and actionable cause.
   - Not needed: explain why available checks would add no meaningful signal.
   - Skipped/blocked: exact gap and why it matters.

## Cadence

For sequential work items:

- Group related small edits into meaningful work items. Do not validate per line, file, or save merely because an edit occurred.
- Decide whether validation is needed for each meaningful work item before choosing checks.
- Run lightweight targeted checks before ending an item only when they cover a plausible failure at reasonable cost.
- Plan heavyweight checks only when integration, shared behavior, public contracts, or other material risk justifies their cost.
- Classify warranted checks as per-item or pre-close integrated validation based on runtime, resource cost, setup cost, and coverage.
- After each item, keep every planned heavyweight check ready: record its exact command, scope, required environment or data, and any setup already completed.
- Defer heavyweight checks by default when later work does not depend on their result. Run them after all implementation items and before closeout.
- Treat `not-needed` items as complete without running checks. When required final validation is pending, treat affected items as implementation-complete but not done until planned heavyweight checks pass.
- If heavyweight validation fails, keep or return affected work to pending, fix the cause, then rerun affected targeted checks and the heavyweight validation.

## Matrix

Bugfix:
- Reproduce or identify current broken behavior.
- Add or update regression coverage when practical.
- Run targeted test that would fail without the fix.

Feature:
- Validate primary success path.
- Validate at least one invalid/edge path when behavior accepts input.
- Check public contracts, docs, or schema if changed.

Refactor:
- Verify behavior is preserved.
- Run typecheck or equivalent static check when available.
- Run tests around touched modules.

UI:
- Open the changed surface when feasible.
- Check desktop and mobile viewports for overlap, overflow, broken layout, and key interactions.
- Use browser screenshots for visual changes when a local target is available.

API:
- Validate request/response shape.
- Run unit/e2e or contract tests.
- Check OpenAPI/schema/client generation impact when present.

Database:
- Validate migration direction and data assumptions.
- Check rollback or recovery path when repo supports it.
- Inspect query/index/performance impact for shared paths.

Config/tooling:
- Run the affected command directly.
- Check generated files or caches only when intentionally changed.
- Confirm local/global config boundary.

Docs:
- Check commands, paths, links, and examples against repo state.
- Ensure docs do not present open decisions as settled.

Dependencies:
- Confirm lockfile/source pairing.
- Run build or focused import check.
- Note runtime or security-sensitive impact.

## Output

```txt
Verify:
- Change type: ...
- Checks run: ...
- Result: pass|fail|not-needed|skipped|blocked
- Gap: ...
```

For `workstream`, required validation must pass before marking affected
Taskwarrior tasks done. `not-needed` work may be marked done without checks.
Skipped or blocked required validation keeps affected tasks pending or blocked
unless the user explicitly accepts deferral.
