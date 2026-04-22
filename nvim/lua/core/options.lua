local util = require("core.util")
local opt = vim.opt
local state_dir = util.writable_stdpath("state", "dotfiles-nvim-state")
local state_paths = {
  backup = state_dir .. "/backup",
  shada = state_dir .. "/shada/main.shada",
  sessions = state_dir .. "/sessions",
  swap = state_dir .. "/swap",
  undo = state_dir .. "/undo",
}

for _, path in pairs(state_paths) do
  if path ~= state_paths.shada then
    util.ensure_dir(path)
  end
end

opt.autoread = true
opt.autowrite = true
opt.backup = true
opt.backupdir = state_paths.backup
opt.backspace = { "indent", "eol", "start" }
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.completeopt = { "menu", "menuone", "noselect" }
opt.confirm = true
opt.cursorline = true
opt.directory = state_paths.swap
opt.expandtab = true
opt.fillchars = { eob = " " }
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep --smart-case --hidden"
opt.hidden = true
opt.history = 1000
opt.hlsearch = true
opt.ignorecase = true
opt.inccommand = "split"
opt.incsearch = true
opt.laststatus = 3
opt.linebreak = true
opt.list = true
opt.listchars = { tab = "> ", trail = ".", nbsp = "+" }
opt.mouse = "a"
opt.number = true
opt.pumheight = 12
opt.relativenumber = true
opt.scrolloff = 4
opt.shadafile = state_paths.shada
opt.sessionoptions = {
  "buffers",
  "curdir",
  "folds",
  "help",
  "localoptions",
  "tabpages",
  "terminal",
  "winsize",
}
opt.shiftround = true
opt.shiftwidth = 2
opt.shortmess:append("c")
opt.showmode = false
opt.signcolumn = "yes"
opt.sidescrolloff = 8
opt.smartcase = true
opt.smartindent = true
opt.softtabstop = 2
opt.splitbelow = true
opt.splitright = true
opt.swapfile = true
opt.tabstop = 2
opt.termguicolors = true
opt.timeoutlen = 300
opt.undodir = state_paths.undo
opt.undofile = true
opt.updatetime = 250
opt.wildmode = { "longest:full", "full" }
opt.wrap = false
opt.writebackup = true

opt.isfname:append("@-@")

vim.g.dotfiles_session_path = state_paths.sessions .. "/last.vim"
