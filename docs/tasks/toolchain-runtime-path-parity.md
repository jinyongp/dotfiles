# Toolchain Runtime Path Parity

Status: `planned`

Suggested priority: `P11`

## Summary

Unify the path and install-location rules used by the installer and the zsh bootstrap layer for Homebrew, fnm, npm global packages, pnpm, and install env files.
The goal is to keep install-time provisioning and shell startup behavior aligned.

## Why this matters

The repo currently defines some toolchain paths and environment rules in more than one place.
That increases the chance that a tool is installed into one location while the interactive or non-interactive shell expects another.

## Proposed direction

- Consolidate shared path rules for Homebrew, fnm, npm global bin, pnpm, and related writable directories.
- Reduce duplication between installer-side helpers and zsh bootstrap helpers without changing the current public install flow.
- Keep shell startup ownership clear so non-interactive and interactive zsh sessions resolve the same toolchain layout.

## Success signals

- Installer-written toolchains and zsh startup resolve the same command paths by default.
- Shared path policy lives in fewer places and is easier to audit.
- Path-related follow-up bugs become less likely when adding new tools or changing install locations.

## Notes / dependencies

- This should examine duplication across `scripts/lib/packages.zsh`, `scripts/lib/recipes/fnm.zsh`, and `zsh/lib/helpers.zsh`.
- It should also account for repeated config and install env path setup where that affects runtime behavior.
- This task should preserve the current non-interactive zsh bootstrap guarantees.
