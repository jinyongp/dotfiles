# Dotfiles

Personal macOS and Linux shell setup: zsh, CLI tools, Neovim, and
machine-local configuration defaults.

## Quick Start

For a new machine, run the bootstrap script.
It clones or updates `~/.dotfiles`, then starts the installer.

```sh
curl -fsSL https://raw.githubusercontent.com/jinyongp/dotfiles/main/scripts/install-remote.bash | bash
```

To inspect the script first:

```sh
curl -fsSLO https://raw.githubusercontent.com/jinyongp/dotfiles/main/scripts/install-remote.bash
less install-remote.bash
bash install-remote.bash
```

To install from a manual checkout:

```sh
git clone https://github.com/jinyongp/dotfiles.git ~/.dotfiles
~/.dotfiles/install
```

## Usage

After shell setup is installed, use the `dotfiles` command.

```sh
dotfiles install
dotfiles list
dotfiles update
dotfiles doctor
```

When no existing `dfx` command is present, zsh also defines `dfx` as a short
alias for `dotfiles`.

Run a specific target when you only want one part of the setup.

```sh
dotfiles install neovim
dotfiles install packages taskwarrior
dotfiles install packages fnm eza
dotfiles install theme
```

The interactive installer is plan-first.
It starts with `Minimal`, `Recommended`, `Full`, or `Custom`, then lets you
review, revise, or cancel the final plan before anything runs.

For the full installer flow, direct install targets, platform notes, and local
config paths, see [`docs/installer.md`](docs/installer.md).

## Uninstall

Run uninstall to remove dotfiles-managed symlinks.
It does not remove packages, apps, fonts, themes, backups, machine-local config,
or a manual checkout.

```sh
dotfiles uninstall -y
```

Backups for files replaced during install live in
`~/.config/dotfiles/backups/<timestamp>`.
Restore those files manually before deleting the repository.
See [`docs/installer.md`](docs/installer.md#uninstall-and-rollback) for the full
rollback checklist.

## What Gets Managed

- zsh startup files and shell helpers
- CLI packages and selected desktop apps
- Neovim config
- themes, fonts, and machine-local Git config helpers

Machine-local overrides live under `~/.config/dotfiles`.
Secrets and per-machine values should stay there, not in this repository.

## Editor

This repo treats Neovim as the primary terminal editor.
The dotfiles setup links the repo-managed Neovim config and keeps plain Vim as a
lightweight fallback.

For editor behavior and formatting rules, see [`docs/editor.md`](docs/editor.md).
For the keymap reference, see [`docs/neovim-keymaps.md`](docs/neovim-keymaps.md).

## More Docs

- Installer details: [`docs/installer.md`](docs/installer.md)
- Editor behavior: [`docs/editor.md`](docs/editor.md)
- Neovim keymaps: [`docs/neovim-keymaps.md`](docs/neovim-keymaps.md)
- Contributing and commit messages: [`docs/contributing.md`](docs/contributing.md)
- Verification and CI: [`docs/verification.md`](docs/verification.md)
