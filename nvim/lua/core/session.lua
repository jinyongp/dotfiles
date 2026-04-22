local M = {}

local function session_path()
  return vim.g.dotfiles_session_path
end

function M.save()
  local path = session_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.cmd("mksession! " .. vim.fn.fnameescape(path))
  vim.notify("Session saved to " .. path, vim.log.levels.INFO)
end

function M.load()
  local path = session_path()

  if vim.fn.filereadable(path) == 0 then
    vim.notify("No saved session found at " .. path, vim.log.levels.WARN)
    return
  end

  vim.cmd("source " .. vim.fn.fnameescape(path))
end

vim.api.nvim_create_user_command("SessionSave", M.save, { desc = "Save the current session" })
vim.api.nvim_create_user_command("SessionLoad", M.load, { desc = "Load the last saved session" })

return M
