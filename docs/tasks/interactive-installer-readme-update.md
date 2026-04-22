# Interactive Installer README Update

Status: `planned`  
Suggested priority: `P6`

## Summary

Update the README so it reflects the current interactive installer flow and keyboard behavior.
This is a documentation sync task, not a product or refactor task.

## Why this matters

The installer has already moved to a plan-first flow with conditional prompts, auto-added modules, reuse notes, and a more structured prompt UI.
README guidance should match the actual experience so new users do not have to infer behavior from the code.

## Proposed direction

- Document the current interactive flow at a high level.
- Include conditional prompt behavior, plan summary expectations, auto-added and reused items, and keyboard interactions.
- Keep the README concise and consistent with the current repository documentation tone.

## Success signals

- A new user can understand the interactive installer without reading implementation code.
- README examples and explanations match the current installer behavior.
- The documentation stays focused on workflow rather than internal implementation details.

## Notes / dependencies

- This should happen after prompt and installer behavior settle enough that the documentation will not immediately drift again.
- The primary target is `README.md`.
