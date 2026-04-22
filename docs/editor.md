# Editor Guide

This repository treats Neovim as the primary terminal editor, with plain Vim kept as a lightweight fallback.

## Installed Result

The dotfiles setup links:

- `~/.config/nvim`
- `~/.vimrc`

If `nvim` is available, shell startup sets:

- `EDITOR=nvim`
- `VISUAL=nvim`
- `vim` and `vi` aliases to `nvim`

## Included Neovim Setup

The repo-managed Neovim config includes:

- file explorer, fuzzy finder, live grep, statusline, bufferline, git signs
- Treesitter, completion, snippets, autopairs, comments, surround, integrated terminal
- LSP-based navigation and refactoring

A shortcut reference for the active keymaps lives in [`docs/neovim-keymaps.md`](./neovim-keymaps.md).

## TypeScript Extras

TypeScript editor extras are installed only when `node` and `npm` already exist on the machine.
This setup does not auto-install Node.

## Formatter and Linter Behavior

JavaScript and TypeScript formatting stays project-respecting:

- Biome is used when a `biome.json` or `biome.jsonc` config exists and the executable is available
- otherwise Prettier is used when a Prettier config exists and the executable is available
- ESLint linting runs only when an ESLint config exists and the executable is available
- if no matching formatter or linter config exists, Neovim falls back to LSP diagnostics and skips JS or TS auto-formatting
