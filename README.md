# Dotfiles

## Installation

Clone the repository to `~/.dotfiles`.

```sh
git clone https://github.com/jinyongp/dotfiles.git ~/.dotfiles
```

Run the interactive installer.

```sh
~/.dotfiles/install
```

Run a single target directly when you only want one part of the setup.

```sh
~/.dotfiles/install neovim
~/.dotfiles/install packages fnm eza
~/.dotfiles/install theme
```

The interactive installer is plan-first: it starts with a profile (`Minimal`, `Recommended`, `Full`, or `Custom`), then lets you review, revise, or cancel the final plan before anything runs.
For the full interactive flow, direct install targets, platform notes, and machine-local config paths, see [`docs/installer.md`](docs/installer.md).

## Editor

This repo treats Neovim as the primary terminal editor.
The dotfiles setup links the repo-managed Neovim config and keeps plain Vim as a lightweight fallback.

For editor behavior and formatting rules, see [`docs/editor.md`](docs/editor.md).
For the keymap reference, see [`docs/neovim-keymaps.md`](docs/neovim-keymaps.md).

## Notes

- Local shell override paths are documented in [`docs/installer.md`](docs/installer.md). Secrets should not be committed into the repository.
- Installer-written machine-local Git files are documented in [`docs/installer.md`](docs/installer.md).
- Commit message rules are documented in [`docs/contributing.md`](docs/contributing.md).
