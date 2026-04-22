# Install Responsibility Split

Status: `planned`  
Suggested priority: `P4`

## Summary

Split the top-level `install` script into smaller focused subsystems without changing user-visible behavior.
The goal is to improve maintainability, reviewability, and future feature work.

## Why this matters

The top-level installer currently owns plan building, interactive prompt flow, direct install behavior, runtime setup, and summary handling.
That makes the file hard to reason about and increases the cost of even small changes.

## Proposed direction

- Extract focused libraries for interactive flow, plan resolution, direct install handling, and runtime or style bootstrap.
- Keep the top-level entrypoint centered on orchestration and CLI routing.
- Preserve the current plan-first install behavior and existing direct install interface.

## Success signals

- The top-level installer becomes meaningfully smaller and easier to scan.
- Related logic lives behind clearer abstraction boundaries.
- Refactors or new installer features no longer require editing one oversized script.

## Notes / dependencies

- This is a larger refactor than the other backlog items and should keep strong smoke coverage around the current flow.
- Prompt rendering safety checks become more valuable before and during this work.
