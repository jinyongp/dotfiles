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

Run a single install target directly.

```sh
~/.dotfiles/install neovim
~/.dotfiles/install packages fnm eza
~/.dotfiles/install theme
```

The top-level installer is a `bash` application. It now builds an installation plan first, then runs it after a final confirmation.
The interactive flow starts with module selection, asks only the follow-up questions needed for the selected modules, and shows a final plan summary before any installation work starts.
That summary also calls out auto-added dependencies, reused existing setup, and any leaf modules that were skipped because no items were selected.
The module list now starts with no preselected entries, so pressing Enter immediately exits cleanly when you do not want to install anything.

Git identity input now stays on the same line as the `>` prompt, validates `user.email`, and shows a review step before continuing. The installer also explains where the machine-local Git personal file lives and that it can be edited directly later.

After the final confirmation, it bootstraps `zsh` only if needed and then hands the selected plan to a non-interactive `zsh` runner. The chosen shell settings are still written to `~/.config/dotfiles/install.env`, a post-install report is printed, and the installer starts a login `zsh` automatically when the repo-managed shell config applies.

If you pass a target name to `install`, the script skips the interactive flow and runs only that module. Leaf modules such as `packages`, `oh_my_zsh`, `fonts`, and `desktop_apps` also accept item IDs as additional arguments. `vim` and `nvim` are accepted as aliases for the `neovim` target.
Direct `neovim` installs also link the repo-managed `~/.config/nvim` immediately, even when the full `dotfiles` module is not selected.

## Editor

The installer now exposes a `Neovim` module instead of the old Vim/Vundle bootstrap. The dotfiles module links both `~/.config/nvim` and a minimal `~/.vimrc`, so Neovim becomes the primary editor while plain Vim still works as a lightweight fallback.

If `nvim` is available, shell startup sets `EDITOR=nvim` and `VISUAL=nvim`, and also aliases `vim` and `vi` to `nvim`.

The curated Neovim config includes:

- file explorer, fuzzy finder, live grep, statusline, bufferline, git signs
- Treesitter, completion, snippets, autopairs, comments, surround, integrated terminal
- TypeScript LSP, rename, code action, organize imports, diagnostics, format-on-save when a matching project formatter is configured

A shortcut reference for the repo-managed Neovim setup lives in [`docs/neovim-keymaps.md`](docs/neovim-keymaps.md).
It covers the essential built-in motions plus the custom leader, LSP, navigation, buffer, and terminal mappings defined by this config.

TypeScript editor extras are installed only when `node` and `npm` already exist on the machine. This setup does not auto-install Node.

Formatter and linter behavior is project-respecting:

- Biome is used when a `biome.json` or `biome.jsonc` config exists and the executable is available
- otherwise Prettier is used when a Prettier config exists and the executable is available
- ESLint linting runs only when an ESLint config exists and the executable is available
- if no matching formatter or linter config exists, Neovim falls back to LSP diagnostics and skips JS/TS auto-formatting

## Notes

- `macOS` always uses Homebrew.
- `WSL` lets you choose between `apt` and `Homebrew on Linux` for the main install flow. If `zsh` is missing, the bootstrap may use `apt` first just to install `zsh`.
- `install list` prints the available direct-install targets for the current platform.
- `base CLI`, `oh-my-zsh`, `fonts`, and `desktop apps` support per-item multiselect prompts.
- Theme, package manager, and Git identity prompts are now conditional and only appear when the selected plan actually needs them.
- Already installed shell themes, CLI packages, and oh-my-zsh plugins are shown with dim status badges in the picker, and installed packages or plugins are disabled to avoid redundant installs.
- Multiselect prompts now use a scrolling viewport so short terminals still show the active item and hidden-item counts.
- `dotfiles`, `neovim`, and `macOS defaults` remain atomic modules.
- Local shell overrides belong in `~/.config/dotfiles/local.zsh`. Secrets should not be committed into the repository.
- Machine-local Git path overrides live in `~/.config/dotfiles/git/root.local.ini` and are written by the installer.
- Machine-local Git identity and signing config live in `~/.config/dotfiles/git/personal.local.ini`.
- `~/.config/dotfiles/git/personal.local.ini` may be created from the bundled example during install, and you can edit it directly later without rerunning the installer.
