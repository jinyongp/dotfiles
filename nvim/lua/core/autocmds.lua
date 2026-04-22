local group = vim.api.nvim_create_augroup("dotfiles_core", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Highlight yanked text",
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "FocusGained" }, {
  group = group,
  desc = "Reload files changed outside of Neovim",
  command = "checktime",
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  desc = "Create missing parent directories on save",
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ":p:h")
    if dir ~= "" then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  desc = "Tidy terminal buffers",
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "help", "lspinfo", "man", "qf", "startuptime" },
  desc = "Close helper windows with q",
  callback = function(args)
    vim.keymap.set("n", "q", "<cmd>close<CR>", {
      buffer = args.buf,
      desc = "Close window",
      silent = true,
    })
  end,
})
