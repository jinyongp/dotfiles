# Install Internal Refactor Follow-ups

Status: `completed`

Suggested priority: `P6`

## Summary

Track the second phase of installer cleanup after the first responsibility split.
The first phase moves code into focused files while intentionally preserving function names, global state, and user-visible behavior.

## Why this matters

The installer is now easier to scan, but its internal API is still mostly the original large-script shape.
Future changes will be safer if the new file boundaries are backed by clearer state ownership, test seams, and naming conventions.

## Proposed direction

- Introduce an `install::` naming convention for new or touched internal functions.
- Replace broad mutable globals with a smaller documented runtime state surface where Bash 3.2 compatibility allows it.
- Add focused shell tests for plan resolution, direct target configuration, and package manager requirement detection.
- Clarify which functions are entrypoint orchestration, prompt UI, plan mutation, status detection, and runner I/O.

## Success signals

- A reader can identify the owner of installer state changes without following calls across every library.
- Plan resolution can be tested without invoking prompt rendering or runner execution.
- New install modules can be added by touching catalog, plan rules, and runner behavior without broad entrypoint edits.

## Notes / dependencies

- Do not combine this with user-facing installer UX changes.
- Keep Bash 3.2 compatibility unless the project explicitly raises the baseline.
- Preserve the current public CLI while tightening internal boundaries.
- The second pass added installer namespace boundaries, centralized bootstrap sourcing, explicit state initialization, and focused plan/direct tests.
