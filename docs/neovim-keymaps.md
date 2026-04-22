# Neovim Keymaps

This repository treats Neovim as the primary terminal editor.
If `nvim` exists, shell startup sets `EDITOR=nvim`, `VISUAL=nvim`, and aliases `vim` and `vi` to `nvim`.

The config uses:

- `Space` as `<leader>`
- `\` as `<localleader>`
- `which-key.nvim`, so pausing briefly after `<leader>` shows available groups

This document focuses on:

- essential built-in Vim motions you will use constantly
- repo-defined keymaps that turn Neovim into an editor-oriented workflow

It does not try to list every default Vim command or every plugin-local action.

## Modes

| Key | Meaning |
| --- | --- |
| `i` | enter insert mode before cursor |
| `a` | enter insert mode after cursor |
| `o` | open a new line below and enter insert mode |
| `O` | open a new line above and enter insert mode |
| `Esc` | return to normal mode |
| `v` | start characterwise visual selection |
| `V` | start linewise visual selection |
| `Ctrl-v` | start blockwise visual selection |

## Basic Movement

| Key | Meaning |
| --- | --- |
| `h` `j` `k` `l` | move left, down, up, right |
| `w` / `b` | move by word forward / backward |
| `e` | jump to end of word |
| `0` / `^` / `$` | line start / first non-blank / line end |
| `gg` / `G` | first line / last line |
| `%` | jump between matching pairs like `()`, `{}`, `[]` |
| `Ctrl-u` / `Ctrl-d` | half-page up / down |
| `Ctrl-o` / `Ctrl-i` | jump backward / forward in location history |

## Editing Basics

| Key | Meaning |
| --- | --- |
| `x` | delete character under cursor |
| `dd` | delete current line |
| `yy` | yank current line |
| `p` / `P` | paste after / before cursor |
| `u` | undo |
| `Ctrl-r` | redo |
| `cw` | change word |
| `ci"` / `ci'` / `ci(` | change inside quotes or parentheses |
| `>>` / `<<` | indent line right / left |
| `=` | re-indent selected text or motion |

## Search

| Key | Meaning |
| --- | --- |
| `/pattern` | search forward |
| `?pattern` | search backward |
| `n` / `N` | next / previous match |
| `*` / `#` | search word under cursor forward / backward |
| `Esc` | clear search highlight in this config |

## File and Session Commands

These are custom mappings defined by this repo.

| Key | Meaning |
| --- | --- |
| `<leader>w` | write current buffer |
| `<leader>qq` | quit all with confirmation |
| `<leader>bd` | delete current buffer |
| `<leader>qs` | save session |
| `<leader>ql` | load last session |

## Window and Buffer Navigation

| Key | Meaning |
| --- | --- |
| `Ctrl-h` | focus left window |
| `Ctrl-j` | focus lower window |
| `Ctrl-k` | focus upper window |
| `Ctrl-l` | focus right window |
| `Shift-h` | previous buffer |
| `Shift-l` | next buffer |

## Explorer, Search, and Terminal

| Key | Meaning |
| --- | --- |
| `<leader>e` | toggle file explorer |
| `<leader>ff` | find files |
| `<leader>fg` | live grep with `ripgrep` |
| `<leader>fb` | list open buffers |
| `<leader>fh` | search help tags |
| `<leader>tt` | toggle integrated terminal |

Notes:

- The file explorer is powered by `neo-tree`.
- Search pickers are powered by `telescope.nvim`.
- The terminal opens horizontally and starts in insert mode.

## Diagnostics and LSP

These mappings become most useful in TypeScript, JavaScript, Lua, and other LSP-enabled files.

| Key | Meaning |
| --- | --- |
| `gd` | go to definition |
| `gr` | list references |
| `gI` | go to implementation |
| `K` | hover documentation |
| `[d` | previous diagnostic |
| `]d` | next diagnostic |
| `<leader>cd` | show diagnostics for current line |
| `<leader>cr` | rename symbol |
| `<leader>ca` | code action |
| `<leader>co` | organize imports |
| `<leader>cf` | format current buffer |

TypeScript-specific behavior:

- the config prefers project-local `typescript-language-server` when available
- the config prefers the project TypeScript SDK when `node_modules/typescript` exists
- formatting is project-respecting: Biome first, then Prettier, otherwise no JS or TS auto-formatting

## Completion and Snippets

In insert mode:

| Key | Meaning |
| --- | --- |
| `Ctrl-Space` | open completion menu |
| `Enter` | confirm selected completion |
| `Tab` | next completion item, or expand or jump snippet |
| `Shift-Tab` | previous completion item, or jump backward in snippet |

## Helper Windows

For `help`, `man`, quickfix, and similar helper buffers:

| Key | Meaning |
| --- | --- |
| `q` | close the window |

## Practical Starter Workflow

If you want to use this setup more like a lightweight editor than a modal toy, this is the shortest path:

1. Open a project with `vi .` or `vi path/to/file.ts`.
2. Press `<leader>e` to browse files, or `<leader>ff` to jump directly to one.
3. Use `Shift-h` and `Shift-l` to move between buffers.
4. Use `gd`, `gr`, `K`, `<leader>cr`, and `<leader>ca` for code navigation and refactors.
5. Use `<leader>fg` for project-wide search.
6. Use `<leader>tt` for an in-editor terminal.
7. Use `<leader>w` to save and `<leader>cf` to format when the project supports it.

## Discoverability

Two built-in habits make this setup easier to learn:

- Press `Space` and wait briefly to let `which-key` show the available leader mappings.
- Use `:map`, `:nmap`, or `:Telescope keymaps` if you want to inspect active mappings from inside Neovim.
