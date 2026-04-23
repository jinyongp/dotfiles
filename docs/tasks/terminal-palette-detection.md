# Terminal Palette Detection

Status: `completed`
Suggested priority: `P4`

## Summary

Refine terminal palette detection while preserving the current default-foreground-first rendering policy.
The goal is to improve readability across light and dark terminals without reintroducing hard-coded bright text failures.

## Why this matters

Recent installer styling work had to back away from fixed bright foreground colors because they failed on light backgrounds.
Terminal background detection is still conservative, so some environments will remain ambiguous unless the behavior is made more explicit.

## Proposed direction

- Review how `scripts/lib/style.sh` detects terminal background and explicit overrides.
- Keep body text on the terminal default foreground and reserve color for structural emphasis and state changes.
- Document fallback behavior for terminals where background cannot be inferred reliably.

## Success signals

- Installer output remains readable on both light and dark backgrounds.
- Explicit override behavior is clear and predictable.
- Palette handling does not depend on fragile terminal-specific assumptions by default.

## Notes / dependencies

- `COLORFGBG` and override environment variables are the main inputs to review first.
- This task should improve confidence in the current policy, not add palette complexity without a clear payoff.
- Completed by documenting the terminal styling contract and adding `scripts/tests/style-palette.sh`.
