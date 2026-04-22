local M = {}

local uv = vim.uv or vim.loop
local path_sep = package.config:sub(1, 1)

local function as_path(input)
  if type(input) == "number" then
    local name = vim.api.nvim_buf_get_name(input)
    if name == "" then
      return uv.cwd() or vim.fn.getcwd()
    end
    return vim.fn.fnamemodify(name, ":p")
  end

  if input == nil or input == "" then
    return uv.cwd() or vim.fn.getcwd()
  end

  return vim.fn.fnamemodify(input, ":p")
end

local function dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

local function search_ancestors(startpath, matcher)
  local path = as_path(startpath)
  local dir = path

  if M.is_file(path) then
    dir = dirname(path)
  end

  while dir and dir ~= "" do
    local match = matcher(dir)
    if match then
      return match
    end

    local parent = dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

function M.join(...)
  local parts = {}

  for _, value in ipairs({ ... }) do
    if type(value) == "table" then
      for _, nested in ipairs(value) do
        parts[#parts + 1] = nested
      end
    elseif value ~= nil then
      parts[#parts + 1] = value
    end
  end

  return table.concat(parts, path_sep)
end

function M.exists(path)
  return path ~= nil and uv.fs_stat(path) ~= nil
end

function M.is_file(path)
  local stat = path and uv.fs_stat(path) or nil
  return stat ~= nil and stat.type == "file"
end

function M.is_dir(path)
  local stat = path and uv.fs_stat(path) or nil
  return stat ~= nil and stat.type == "directory"
end

function M.project_root(startpath)
  local markers = {
    "package.json",
    "tsconfig.json",
    "jsconfig.json",
    "biome.json",
    "biome.jsonc",
    ".git",
  }

  return search_ancestors(startpath, function(dir)
    for _, marker in ipairs(markers) do
      local candidate = M.join(dir, marker)
      if M.exists(candidate) then
        return dir
      end
    end
  end) or dirname(as_path(startpath))
end

function M.find_upward(startpath, names)
  return search_ancestors(startpath, function(dir)
    for _, name in ipairs(names) do
      local candidate = M.join(dir, name)
      if M.exists(candidate) then
        return candidate
      end
    end
  end)
end

function M.package_json_has_key(startpath, key)
  local package_json = M.find_upward(startpath, { "package.json" })

  if not package_json or not M.is_file(package_json) then
    return false
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json), "\n"))
  return ok and type(decoded) == "table" and decoded[key] ~= nil
end

function M.resolve_executable(startpath, names)
  local candidates = type(names) == "table" and names or { names }

  for _, name in ipairs(candidates) do
    local local_bin = M.find_upward(startpath, { M.join("node_modules", ".bin", name) })
    if local_bin and vim.fn.executable(local_bin) == 1 then
      return local_bin
    end

    local global_bin = vim.fn.exepath(name)
    if global_bin ~= "" then
      return global_bin
    end
  end

  return nil
end

function M.find_typescript_lib(startpath)
  local match = M.find_upward(startpath, {
    M.join("node_modules", "typescript", "lib", "tsserverlibrary.js"),
  })

  if match then
    return dirname(match)
  end

  return nil
end

function M.is_javascript_or_typescript(filetype)
  return ({
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
    jsx = true,
    tsx = true,
  })[filetype] == true
end

function M.has_biome_config(startpath)
  return M.find_upward(startpath, { "biome.json", "biome.jsonc" }) ~= nil
end

function M.has_prettier_config(startpath)
  local config_names = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
  }

  return M.find_upward(startpath, config_names) ~= nil or M.package_json_has_key(startpath, "prettier")
end

function M.has_eslint_config(startpath)
  local config_names = {
    ".eslintrc",
    ".eslintrc.json",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    "eslint.config.js",
    "eslint.config.cjs",
    "eslint.config.mjs",
    "eslint.config.ts",
  }

  return M.find_upward(startpath, config_names) ~= nil or M.package_json_has_key(startpath, "eslintConfig")
end

function M.javascript_formatters(startpath)
  if M.has_biome_config(startpath) and M.resolve_executable(startpath, { "biome" }) then
    return { "biome" }
  end

  if M.has_prettier_config(startpath) and M.resolve_executable(startpath, { "prettier" }) then
    return { "prettier" }
  end

  return {}
end

return M
