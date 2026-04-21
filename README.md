# Dotfiles

## Installation

Clone your dotfiles repository to `~/.dotfiles`

```sh
git clone https://github.com/jinyongp/dotfiles.git ~/.dotfiles
```

Run the interactive installer.

```sh
~/.dotfiles/install
```

The top-level installer is a `bash` application. It handles the full interactive prompt flow, including module selection, per-item selection, theme choice, and optional machine-local Git identity input.

After the final confirmation, it bootstraps `zsh` only if needed and then hands the selected plan to a non-interactive `zsh` runner. The chosen shell settings are still written to `~/.config/dotfiles/install.env`.

## Notes

- `macOS` always uses Homebrew.
- `WSL` lets you choose between `apt` and `Homebrew on Linux` for the main install flow. If `zsh` is missing, the bootstrap may use `apt` first just to install `zsh`.
- `base CLI`, `oh-my-zsh`, `fonts`, and `desktop apps` support per-item multiselect prompts.
- `dotfiles`, `vim`, and `macOS defaults` remain atomic modules.
- Local shell overrides belong in `~/.config/dotfiles/local.zsh`. Secrets should not be committed into the repository.
- Machine-local Git path overrides live in `~/.config/dotfiles/git/root.local.ini` and are written by the installer.
- Machine-local Git identity and signing config live in `~/.config/dotfiles/git/personal.local.ini`.
