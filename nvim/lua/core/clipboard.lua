local M = {}

local warned = {
  copy = false,
  paste = false,
}

local cached_registers = {
  ["+"] = nil,
  ["*"] = nil,
}

local function executable(command)
  return vim.fn.executable(command) == 1
end

local function in_tmux()
  return vim.env.TMUX and vim.env.TMUX ~= ""
end

local function in_ssh()
  return vim.env.SSH_TTY and vim.env.SSH_TTY ~= ""
end

local function notify_once(kind, message)
  if warned[kind] then
    return
  end

  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  warned[kind] = true
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
end

local function can_use_osc52()
  if #vim.api.nvim_list_uis() == 0 then
    return false
  end

  if executable("tmux") and in_tmux() then
    return true
  end

  if in_ssh() then
    return true
  end

  if vim.env.TERM_PROGRAM == "iTerm.app" or vim.env.TERM_PROGRAM == "WezTerm" then
    return true
  end

  if vim.env.KITTY_WINDOW_ID or vim.env.GHOSTTY_RESOURCES_DIR then
    return true
  end

  local termfeatures = vim.g.termfeatures or {}
  return termfeatures.osc52 == true
end

local function normalize_regtype(regtype)
  if type(regtype) == "string" and regtype ~= "" then
    return regtype
  end

  return "v"
end

local function normalize_lines(lines)
  if type(lines) == "table" then
    return vim.deepcopy(lines)
  end

  if lines == nil then
    return {}
  end

  return { tostring(lines) }
end

local function cache_register(reg, lines, regtype)
  cached_registers[reg] = {
    normalize_lines(lines),
    normalize_regtype(regtype),
  }
end

local function system_text(lines, regtype)
  local text = table.concat(normalize_lines(lines), "\n")

  if normalize_regtype(regtype) == "V" then
    text = text .. "\n"
  end

  return text
end

local function as_paste_result(reg, lines)
  local normalized_lines = normalize_lines(lines)
  local cached = cached_registers[reg]

  if cached and vim.deep_equal(cached[1], normalized_lines) then
    return { vim.deepcopy(cached[1]), cached[2] }
  end

  return { normalized_lines, "v" }
end

local function try_system(command, input)
  vim.fn.system(command, input)
  return vim.v.shell_error == 0
end

local function try_systemlist(command)
  local result = vim.fn.systemlist(command)
  if vim.v.shell_error == 0 then
    return result
  end
end

local function osc52_copy(reg, lines, regtype)
  if not can_use_osc52() then
    return false
  end

  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return false
  end

  local copy = osc52.copy(reg)
  return pcall(copy, lines, regtype)
end

local function osc52_paste(reg)
  if not can_use_osc52() then
    return nil
  end

  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return nil
  end

  local paste = osc52.paste(reg)
  local paste_ok, result = pcall(paste)

  if paste_ok and type(result) == "table" then
    return result
  end
end

local function copy_to_clipboard(reg, lines, regtype)
  local text = system_text(lines, regtype)
  cache_register(reg, lines, regtype)

  if vim.fn.has("mac") == 1 and executable("pbcopy") and try_system({ "pbcopy" }, text) then
    return
  end

  if executable("tmux") and in_tmux() then
    if try_system({ "tmux", "load-buffer", "-w", "-" }, text) then
      return
    end

    if try_system({ "tmux", "load-buffer", "-" }, text) then
      return
    end
  end

  if osc52_copy(reg, lines, regtype) then
    return
  end

  notify_once("copy", "Clipboard copy fallback was not available in this terminal session.")
end

local function paste_from_clipboard(reg)
  if vim.fn.has("mac") == 1 and executable("pbpaste") then
    local result = try_systemlist({ "pbpaste" })
    if result then
      return as_paste_result(reg, result)
    end
  end

  if executable("tmux") and in_tmux() then
    local result = try_systemlist({ "tmux", "save-buffer", "-" })
    if result then
      return as_paste_result(reg, result)
    end
  end

  local result = osc52_paste(reg)
  if result then
    return as_paste_result(reg, result)
  end

  notify_once("paste", "Clipboard paste fallback was not available in this terminal session.")
  return { {}, "v" }
end

if vim.g.clipboard == nil and vim.fn.has("wsl") == 1 and executable("win32yank.exe") then
  vim.g.clipboard = "win32yank"
  return M
end

if vim.g.clipboard == nil and vim.fn.has("mac") == 1 and not in_tmux() and not in_ssh() then
  vim.g.clipboard = "pbcopy"
  return M
end

if vim.g.clipboard == nil and (vim.fn.has("mac") == 1 or in_tmux() or in_ssh() or vim.fn.has("wsl") == 1) then
  vim.g.clipboard = {
    name = "smart-clipboard",
    copy = {
      ["+"] = function(lines, regtype)
        copy_to_clipboard("+", lines, regtype)
      end,
      ["*"] = function(lines, regtype)
        copy_to_clipboard("*", lines, regtype)
      end,
    },
    paste = {
      ["+"] = function()
        return paste_from_clipboard("+")
      end,
      ["*"] = function()
        return paste_from_clipboard("*")
      end,
    },
    cache_enabled = 0,
  }
end

return M
