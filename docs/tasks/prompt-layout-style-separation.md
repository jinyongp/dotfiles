# Prompt Layout and Style Separation

Status: `planned`  
Suggested priority: `P2`

## Summary

Separate prompt layout decisions from prompt styling decisions.
The goal is to make future UI tuning cheaper and reduce the amount of cross-cutting edits required for small visual changes.

## Why this matters

The current prompt code mixes structure and presentation in the same layer.
Small changes such as moving keyboard hints, adjusting rails, or changing marker emphasis currently touch the same code paths that also define style and color behavior.

## Proposed direction

- Introduce a clearer boundary between layout primitives and style primitives inside the prompt system.
- Treat block composition, metadata placement, option rendering, and tail rails as layout concerns.
- Treat frame appearance, title emphasis, keycap styling, active or disabled states, and badges as style concerns.

## Success signals

- Common prompt tweaks can be made without rewriting unrelated rendering logic.
- Layout changes and style changes can be reviewed independently.
- The prompt library becomes easier to extend with alternate UI modes later.

## Notes / dependencies

- This task becomes safer once prompt rendering snapshots exist.
- The target is refactoring, not changing the installer flow or visible UX on purpose.
