# Install UI Modes

Status: `completed`
Suggested priority: `P8`

## Summary

Evaluate support for multiple installer UI modes such as `plain`, `compact`, and `rich`.
The goal is to make the installer easier to use across local terminals, remote shells, and constrained environments.

## Why this matters

The current prompt UI is richer than before, but not every terminal session benefits from the same amount of structure or styling.
Some environments need a simpler fallback without losing the plan-first flow or keyboard guidance.

## Proposed direction

- Define a small set of installer UI modes with clear rendering expectations.
- Keep the plan flow and installation behavior identical across modes.
- Ensure the simpler modes still communicate selection state, keyboard controls, and final confirmation clearly.

## Success signals

- Installer output remains usable in limited terminals, SSH sessions, and low-capability environments.
- Rich mode can keep the more expressive layout without becoming the only supported presentation.
- UI complexity becomes an explicit choice rather than an accidental property of the current renderer.

## Notes / dependencies

- This work benefits from separating prompt layout from prompt styling first.
- It should reuse the same core prompt semantics instead of creating multiple independent prompt implementations.
