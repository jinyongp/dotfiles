# Install Summary Actions

Status: `completed`

Suggested priority: `P7`

## Summary

Add summary-stage actions so the final plan review can branch back into module, item, or Git edits without restarting `./install`.
The goal is to keep the default path short while still making late corrections cheap.

## Why this matters

The installer flow is now shorter, but changing one earlier choice still tends to mean restarting the interactive session.
The final summary is already the natural checkpoint where users notice omissions, over-selection, or Git setup decisions they want to revise.

## Proposed direction

- Replace the final summary's single confirm-or-cancel decision with a small action menu.
- Keep non-`custom` plans profile-first by reopening the profile picker instead of exposing direct module editing.
- Preserve current leaf-item and Git choices when the user revisits the summary without explicitly changing them.
- Reuse the existing module, leaf-item, and Git prompts instead of creating separate edit-only flows.

## Success signals

- The fastest happy path still reaches installation with minimal extra prompts.
- A user can revise modules, item selections, or Git setup from the summary step without restarting the installer.
- Summary-stage edits do not create duplicate plan logic or inconsistent state transitions.

## Notes / dependencies

- The implementation keeps the current direct install CLI and runner order unchanged.
- Summary actions reuse the existing prompt renderer and extend shell-only installer coverage with summary action tests.
