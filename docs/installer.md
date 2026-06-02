# Installer Guide

This document covers the interactive installer, direct install targets, and machine-local files written by the setup flow.

## Interactive Flow

Clone the repository, then run the top-level installer from the repo root or from `~/.dotfiles`.

```sh
git clone https://github.com/jinyongp/dotfiles.git ~/.dotfiles
~/.dotfiles/install
```

After the shell dotfiles are installed, `$DOTFILES/cmd` is available on `PATH`, so the same flow is available through the `dotfiles` command.

```sh
dotfiles install
dotfiles list
dotfiles update
dotfiles doctor
```

When no existing `dfx` command is installed, zsh defines `dfx` as a short alias for `dotfiles`.

The remote bootstrap script is a shortcut for new machines.
It clones or fast-forwards the repository first, then runs the installer.

```sh
curl -fsSL https://raw.githubusercontent.com/jinyongp/dotfiles/main/scripts/install-remote.bash | bash
```

To inspect the remote bootstrap before running it:

```sh
curl -fsSLO https://raw.githubusercontent.com/jinyongp/dotfiles/main/scripts/install-remote.bash
less install-remote.bash
bash install-remote.bash
```

From inside an existing checkout, the installer can still be run directly.

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

Set `DOTFILES_INSTALL_UI_MODE=plain|compact|rich` to choose the interactive installer presentation.
`compact` is the default.
`plain` keeps the same keyboard flow with ASCII-only markers and inline status text.
`rich` keeps the more spaced layout with right-aligned status badges.

## Direct Install Targets

You can skip the interactive flow and run a single target directly.

```sh
dotfiles install neovim
dotfiles install agents
dotfiles install agents codex
dotfiles agents list
dotfiles agents sync
dotfiles install packages taskwarrior
dotfiles install packages fnm eza
dotfiles install theme
```

Notes:

- `dotfiles list` prints the available direct-install targets for the current platform
- direct `./install ...` still works from inside the repository
- leaf modules such as `packages`, `oh_my_zsh`, `fonts`, and `desktop_apps` accept item IDs after the target name
- `vim` and `nvim` are accepted as aliases for the `neovim` target
- direct `neovim` installs also link the repo-managed `~/.config/nvim`
- direct `agents` installs shared AI agent rules for detected tools; pass `codex` to prepare Codex config even when the CLI is not installed
- `dotfiles agents sync` updates external agent skills separately from install
- `packages taskwarrior` installs the real Taskwarrior binary; the repo-managed `cmd/task` shim stays ahead in PATH and delegates to that binary

## Conditional Prompts

The interactive installer only asks questions that matter for the selected plan.

Examples:

- theme selection appears only when shell-related choices need it
- package manager selection appears only when the chosen plan needs package-backed installs
- Git identity is requested only when the selected plan needs dotfiles Git setup
- Git identity uses `Reuse existing`, `Skip for now`, or `Configure now` so existing machine-local values can stay untouched

For multi-item prompts such as CLI packages, fonts, and desktop apps:

- already installed entries are shown with status badges
- installed entries remain navigable for review, but cannot be toggled for redundant reinstalls
- required companion items are added automatically when a selected item needs them
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
AI agent setup is intentionally additive. `./install agents` keeps shared rule files in the repo-managed `agents/rules/` directory and shared skill sources in `agents/skills/`, then adds or updates a marked include block in `~/.codex/AGENTS.md`.
For Codex, it also links the shared `caveman`, `git-commit`, `planning`, `review-loop`, and `taskwarrior` skills into `~/.codex/skills/<name>` when the target path does not already exist.
External skills are declared as source records plus artifact records. Sources define the Git repository URL and ref. Artifacts define the skill path, install name, target adapters, kind, and copy policy. During `./install agents`, the installer downloads missing or stale external skill artifacts into `~/.config/dotfiles/agents/external-skills/<artifact>`, records the resolved revision and artifact metadata in `~/.config/dotfiles/agents/external-skills.lock`, and links each artifact only into its configured adapters. Artifacts that use repo-internal symlinks can opt into symlink materialization so cached skills stay self-contained. Run `dotfiles agents sync [skill...]` to fetch the latest configured refs later.
It does not replace tool home directories and does not manage auth, sessions, history, sqlite files, caches, plugin caches, worktrees, or other local runtime state.

Taskwarrior project-local mode is opt-in per repository. When `.taskwarrior/taskrc` exists in the current directory or a parent, the repo-managed `cmd/task` shim sets `TASKRC` and `TASKDATA` to that project before delegating to the real Taskwarrior binary. If no project-local config is found, it falls back to the normal global Taskwarrior config.

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
