# Installer Guide

This document covers the interactive installer, direct install targets, and machine-local files written by the setup flow.

## Interactive Flow

Run the top-level installer from the repo root or from `~/.dotfiles`.

```sh
./install
```

The interactive flow is plan-based:

1. detect the current environment
2. choose an installation profile: `Minimal`, `Recommended`, `Full`, or `Custom`
3. adjust modules or item selections only when the selected profile needs it
4. answer only the follow-up prompts needed for that plan
5. review the final plan summary
6. proceed, revise the plan, or cancel from the summary actions

Profiles are shortcuts for the first plan draft:

- `Minimal` selects only the core dotfiles links
- `Recommended` selects dotfiles, base CLI packages, and Neovim with editable package defaults
- `Full` selects every visible module for the current platform with editable defaults for leaf-item modules
- `Custom` keeps the fully manual module picker

For `Recommended` and `Full`, the installer now keeps the profile defaults unless you explicitly choose `Review selected items?`.
That single gate opens the existing package, plugin, font, or app pickers only when you want to adjust the preselected plan.
`Minimal` skips leaf-item review entirely, and `Custom` still opens the detailed pickers directly.

The summary can include:

- selected installation profile
- auto-added dependencies
- reused existing setup
- leaf modules removed because no items were selected

The final summary is also the last edit checkpoint before installation starts.
Depending on the current plan, it can offer actions such as:

- `Proceed`
- `Edit profile` or `Edit modules`
- `Edit selected items`
- `Edit Git identity`
- `Cancel`

Profile and module edits rerun the conditional follow-up prompts needed for the new plan.
Item edits reopen only the current package, plugin, font, or app selections.
Git edits reopen the machine-local Git identity flow without restarting the installer.

The `Custom` module picker starts with no selected modules, so pressing `Enter` there exits without installing anything.

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
- Git identity uses `Reuse existing`, `Skip for now`, or `Configure now` so existing machine-local values can stay untouched

For multi-item prompts such as CLI packages, fonts, and desktop apps:

- already installed entries are shown with status badges
- installed entries can be disabled to avoid redundant reinstalls
- scrolling indicators appear in short terminals when not all rows fit at once

## Terminal Styling

Installer styling keeps normal body text on the terminal default foreground so it stays readable across light and dark backgrounds.
Color is reserved for prompt markers, selected states, warnings, errors, and key hints.

Background detection uses this order:

1. `DOTFILES_COLOR_SCHEME=light|dark`
2. `COLORFGBG`, using the last semicolon-separated field as the background color code
3. `unknown`, which keeps the conservative default-foreground-first palette

Set `DOTFILES_COLOR_SCHEME=light` or `DOTFILES_COLOR_SCHEME=dark` if your terminal does not expose useful `COLORFGBG` data.
Set `NO_COLOR=1`, `TERM=dumb`, or `CLICOLOR=0` to disable ANSI styling.
Use `DOTFILES_FORCE_COLOR=1`, `FORCE_COLOR=1`, or `CLICOLOR_FORCE=1` when you need ANSI styling in a non-TTY or otherwise restricted shell.

## Platform Notes

- macOS uses Homebrew
- WSL can choose between `apt` and Homebrew on Linux for the main flow
- if `zsh` is missing on WSL, bootstrap may use `apt` first to install `zsh`

## Local Files

Machine-local overrides and generated config live outside the repository.

- universal shell overrides: `~/.config/dotfiles/env.zsh`
- login-shell overrides: `~/.config/dotfiles/profile.zsh`
- interactive shell overrides: `~/.config/dotfiles/local.zsh`
- backups for replaced linked files: `~/.config/dotfiles/backups/<timestamp>`
- Git path overrides: `~/.config/dotfiles/git/root.local.ini`
- Git identity and signing config: `~/.config/dotfiles/git/personal.local.ini`

The installer creates the shell override files with header comments when they do not already exist.
Existing override files are preserved.

The personal Git file may be created from the bundled example during install and can be edited directly later without rerunning the installer.

Some tools append setup lines to `~/.zshenv` or `~/.zprofile` during installation.
Because those files are repo-managed here, move those machine-local lines into the matching override file instead.

Examples:

- Cargo/Rust: `. "$HOME/.cargo/env"` belongs in `~/.config/dotfiles/env.zsh`
- OrbStack: `source ~/.orbstack/shell/init.zsh 2>/dev/null || :` belongs in `~/.config/dotfiles/profile.zsh`
- Homebrew: `eval "$(/opt/homebrew/bin/brew shellenv)"` is already handled by the repo bootstrap and does not need a local override

## Zsh Startup Files

The dotfiles module manages `~/.zshenv`, `~/.zprofile`, and `~/.zshrc` together.
If any of those files already exist, the installer moves them into `~/.config/dotfiles/backups/<timestamp>` before linking the repo-managed versions.

Startup responsibilities are split by shell phase:

- `~/.zshenv` loads the minimal non-interactive-safe environment, including Homebrew, fnm, npm global bin, and pnpm paths
- `~/.zprofile` loads login-shell-only local overrides
- `~/.zshrc` loads interactive behavior such as aliases, completions, themes, plugins, and oh-my-zsh

## Managed File Headers

Repo-managed files that are linked into `$HOME` include a short header at the top.
The header documents where the file is loaded, where machine-local overrides should go, and what should not be edited directly.

For linked directories such as `~/.config/nvim`, the entrypoint file carries the header.
Generated lock files and data files are not given prose headers when their file format does not allow comments.

## Shell Handoff

When the selected plan applies repo-managed shell configuration, the installer can finish by starting a login `zsh` so the new shell setup takes effect immediately.
