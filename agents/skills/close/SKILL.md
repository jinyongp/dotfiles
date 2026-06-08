---
name: close
description: >
  Close out implementation work by checking plan completion, Taskwarrior queue
  status, validation results, review findings, git status, residual risk, and
  commit readiness. Use when the user asks to close, finish, wrap up, 마감,
  완료 정리, 종료 정리, or when workstream reaches its closeout phase. Does not
  commit by itself; delegates commits to git-commit only when requested.
---

# Close

Decide whether work is actually complete. Do not stage, commit, or mutate tasks
unless the active workflow already permits it and target is clear.

## Checks

1. Plan
   - Confirm `Goal` satisfied.
   - Confirm `Work Items` done or explicitly deferred.
   - Confirm `Validation` run, skipped, or blocked with exact reason.
   - Confirm unresolved decisions were not hidden in docs.

2. Taskwarrior
   - Load `taskwarrior` before reads or mutations.
   - Check `task project:<slug> +PENDING list`.
   - Check `task project:<slug> blocked` when dependencies were used.
   - Do not mark broad task sets done without explicit scope.

3. Review
   - Confirm review-loop ran when risk warranted it.
   - Confirm in-scope actionable findings are fixed.
   - Follow-up tasks are allowed only for out-of-scope findings or user-approved deferrals.

4. Git
   - Run `git status --short`.
   - Inspect diff scope when code changed.
   - Flag unrelated, generated, secret, env, or accidental files.
   - Do not revert unrelated user changes.

5. Commit readiness
   - Ready only when validation passed and diff scope matches request.
   - Skipped or blocked validation is not commit-ready unless the user explicitly accepts the residual risk.
   - If user asks for commit, load `git-commit`.

## Output

```txt
Close:
- Plan: complete|partial|blocked
- Tasks: clear|pending|blocked
- Validation: pass|fail|skipped|blocked
- Review: clean|findings|not-run
- Git: clean|dirty-in-scope|dirty-mixed
- Risk: ...
- Next: ...
```

Keep closeout terse, but include exact failed/skipped commands and residual
risk when present.
