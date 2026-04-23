-- Managed By
--   This file is managed by ~/.dotfiles and linked through ~/.config/nvim.
--
-- Loaded As
--   Neovim entrypoint.
--
-- Local Overrides
--   Keep machine-local editor changes outside this repo-managed config unless
--   they should be shared across all machines using these dotfiles.
--
-- Notes
--   See docs/neovim-keymaps.md for the keymap reference.

local util = require("core.util")

local function running_in_automation()
  return vim.env.CI
    or vim.env.CODEX_CI
    or vim.env.CODEX_SANDBOX
    or vim.env.CODEX_THREAD_ID
    or vim.env.AGENT_SHELL
    or vim.env.AUTOMATION_SHELL
end

if #vim.api.nvim_list_uis() == 0 and running_in_automation() then
  local tmp_root = (vim.uv or vim.loop).os_tmpdir()
  vim.env.XDG_CACHE_HOME = util.join(tmp_root, "dotfiles-nvim-cache")
  vim.env.XDG_STATE_HOME = util.join(tmp_root, "dotfiles-nvim-state")
  util.ensure_dir(vim.fn.stdpath("cache"))
  util.ensure_dir(vim.fn.stdpath("state"))
end

if vim.loader and util.is_writable_dir(vim.fn.stdpath("cache")) then
  vim.loader.enable()
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("core.clipboard")
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.lazy")
