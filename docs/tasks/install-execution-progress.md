# Install Execution Progress

Status: `planned`

Suggested priority: `P9`

## Summary

Refine the execution-time installer output so it is as structured and readable as the planning flow.
The goal is to make install, reuse, skip, and failure states obvious while preserving the current execution order.

## Why this matters

The planning stage is now much easier to follow than before, but the actual installation run still exposes more raw script output and less consistent state signaling.
Users should be able to tell what happened without scanning every line or inferring whether a step was skipped, reused, or actually installed.

## Proposed direction

- Standardize module-level progress reporting across install steps.
- Make reused and skipped work explicit instead of letting it blend into normal output.
- Keep detailed command output available where needed, but frame it under a clear module status model.
- Add a short final execution summary that matches the plan vocabulary where practical.

## Success signals

- A user can identify which modules installed, reused existing state, skipped work, or failed.
- Failures are visually isolated enough that the broken step is obvious without searching the whole log.
- Execution output feels like a continuation of the planner instead of a different UI entirely.

## Notes / dependencies

- This should preserve the current runner execution order and dependency safety.
- It should coordinate with any future installer UI mode work instead of creating a second one-off renderer.
- Snapshot-style prompt tests may not cover this directly, so shell smoke tests will need stronger execution assertions.
