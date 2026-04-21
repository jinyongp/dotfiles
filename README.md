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

The top-level installer is a `bash` bootstrap. If `zsh` is missing, it installs `zsh` first and then launches the interactive installer.

The interactive installer detects `macOS`, `WSL`, and Linux environments, asks which modules to install, and stores the chosen shell settings in `~/.config/dotfiles/install.env`.

## Notes

- `macOS` always uses Homebrew.
- `WSL` lets you choose between `apt` and `Homebrew on Linux` for the main install flow. If `zsh` is missing, the bootstrap may use `apt` first just to install `zsh`.
- Local shell overrides belong in `~/.config/dotfiles/local.zsh`. Secrets should not be committed into the repository.
- Machine-local Git path overrides live in `~/.config/dotfiles/git/root.local.ini` and are written by the installer.
- Machine-local Git identity and signing config live in `~/.config/dotfiles/git/personal.local.ini`.
