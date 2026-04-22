# Installer Guide

This document covers the interactive installer, direct install targets, and machine-local files written by the setup flow.

## Interactive Flow

Run the top-level installer from the repo root or from `~/.dotfiles`.

```sh
./install
```

The interactive flow is plan-based:

1. detect the current environment
2. choose the modules you want
3. answer only the follow-up prompts needed for that plan
4. review the final plan summary
5. confirm before any installation work starts

The summary can include:

- auto-added dependencies
- reused existing setup
- leaf modules removed because no items were selected

Nothing is preselected in the first module picker, so pressing `Enter` immediately exits without installing anything.

## Direct Install Targets

You can skip the interactive flow and run a single target directly.

```sh
./install neovim
./install packages fnm eza
./install theme
```

Notes:

- `install list` prints the available direct-install targets for the current platform
- leaf modules such as `packages`, `oh_my_zsh`, `fonts`, and `desktop_apps` accept item IDs after the target name
- `vim` and `nvim` are accepted as aliases for the `neovim` target
- direct `neovim` installs also link the repo-managed `~/.config/nvim`

## Conditional Prompts

The interactive installer only asks questions that matter for the selected plan.

Examples:

- theme selection appears only when shell-related choices need it
- package manager selection appears only when the chosen plan needs package-backed installs
- Git identity is requested only when the selected plan needs dotfiles Git setup

For multi-item prompts such as CLI packages, fonts, and desktop apps:

- already installed entries are shown with status badges
- installed entries can be disabled to avoid redundant reinstalls
- scrolling indicators appear in short terminals when not all rows fit at once

## Platform Notes

- macOS uses Homebrew
- WSL can choose between `apt` and Homebrew on Linux for the main flow
- if `zsh` is missing on WSL, bootstrap may use `apt` first to install `zsh`

## Local Files

Machine-local overrides and generated config live outside the repository.

- shell overrides: `~/.config/dotfiles/local.zsh`
- Git path overrides: `~/.config/dotfiles/git/root.local.ini`
- Git identity and signing config: `~/.config/dotfiles/git/personal.local.ini`

The personal Git file may be created from the bundled example during install and can be edited directly later without rerunning the installer.

## Shell Handoff

When the selected plan applies repo-managed shell configuration, the installer can finish by starting a login `zsh` so the new shell setup takes effect immediately.
