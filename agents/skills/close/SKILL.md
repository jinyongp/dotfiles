---
name: close
description: >
  Close out implementation work by checking plan completion, validation results, git status, residual risk, and commit readiness.
  Use when the user asks to close, finish, wrap up, 마감,
  완료 정리, 종료 정리. Does not
  commit by itself; delegates commits to git-commit only when requested.
---

# Close

Decide whether work is actually complete. Do not stage, commit, or mutate tasks
unless the active workflow already permits it and target is clear.
Inspect existing completion evidence only. Do not initiate new implementation,
validation, or other quality workflows during closeout.

## Checks

1. Plan
   - Confirm `Goal` satisfied.
   - Confirm `Work Items` done or explicitly deferred.
   - Confirm `Validation` passed, was `not-needed`, or is skipped or blocked with exact reason.
   - Confirm every required pre-close heavyweight check ran after the final implementation change and passed.
   - Do not declare overall completion while required heavyweight validation is pending or failed.
   - Confirm unresolved decisions were not hidden in docs.

2. Git
   - Run `git status --short`.
   - Inspect diff scope when code changed.
   - Flag unrelated, generated, secret, env, or accidental files.
   - Do not revert unrelated user changes.

3. Commit readiness
   - Ready only when required validation passed or was `not-needed`, and diff scope matches request.
   - Skipped or blocked required validation is not commit-ready unless the user explicitly accepts the residual risk.
   - If user asks for commit, load `git-commit`.

## Output

```txt
Close:
- Plan: complete|partial|blocked
- Validation: pass|fail|not-needed|skipped|blocked
- Git: clean|dirty-in-scope|dirty-mixed
- Risk: ...
- Next: ...
```

Keep closeout terse, but include exact failed/skipped commands and residual
risk when present.
