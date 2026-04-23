# Prompt Rendering Snapshots

Status: `completed`
Suggested priority: `P2`

## Summary

Add automated rendering coverage for the current interactive prompt UI.
The goal is to validate prompt output shapes and visible states without relying only on manual TTY checks.

## Why this matters

Recent prompt work changed rails, branch lines, key hints, markers, and installed-state badges quickly.
Those changes are currently easy to regress because most verification is still visual and manual.

## Proposed direction

- Add a small rendering test harness for `scripts/lib/prompt.bash`.
- Capture stable output for `select`, `multiselect`, `text`, completed blocks, and disabled or installed option states.
- Keep snapshots focused on structure and visible behavior rather than full installer execution.

## Success signals

- Prompt regressions are caught before they reach manual smoke testing.
- Changes to rails, branch endings, markers, and keyboard hints can be reviewed against stable output.
- Manual TTY checks become a final verification step instead of the only safety net.

## Notes / dependencies

- This task should treat the current prompt UI as the baseline, not redesign it.
- `scripts/lib/prompt.bash` is the primary target, with only minimal harness code around it.
- Completed with `scripts/tests/prompt-rendering.sh` and stored prompt snapshots under `scripts/tests/prompt-snapshots/`.
