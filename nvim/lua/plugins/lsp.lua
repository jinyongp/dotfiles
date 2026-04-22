local util = require("core.util")

local function lsp_clients(bufnr)
  if type(vim.lsp.get_clients) == "function" then
    return vim.lsp.get_clients({ bufnr = bufnr })
  end

  return vim.lsp.buf_get_clients(bufnr)
end

local function enable_inlay_hints(bufnr)
  if not vim.lsp.inlay_hint or type(vim.lsp.inlay_hint.enable) ~= "function" then
    return
  end

  pcall(vim.lsp.inlay_hint.enable, bufnr, true)
  pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
end

local function organize_imports(bufnr)
  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" }, diagnostics = {} }
  local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1500) or {}

  for client_id, result in pairs(results) do
    for _, action in ipairs(result.result or {}) do
      local client = vim.lsp.get_client_by_id(client_id)

      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client and client.offset_encoding or "utf-16")
      end

      if action.command then
        vim.lsp.buf.execute_command(action.command)
      end
    end
  end
end

local function on_attach(client, bufnr)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
  end

  if client.name == "ts_ls" or client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = false
  end

  map("gd", vim.lsp.buf.definition, "Go to definition")
  map("gr", vim.lsp.buf.references, "Go to references")
  map("gI", vim.lsp.buf.implementation, "Go to implementation")
  map("K", vim.lsp.buf.hover, "Hover")
  map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
  map("<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("<leader>co", function()
    organize_imports(bufnr)
  end, "Organize imports")

  if util.is_javascript_or_typescript(vim.bo[bufnr].filetype) then
    enable_inlay_hints(bufnr)
  end
end

local function capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  if ok then
    caps = cmp_nvim_lsp.default_capabilities(caps)
  end

  return caps
end

local function available_lsp_config(names)
  for _, name in ipairs(names) do
    if #vim.api.nvim_get_runtime_file(("lsp/%s.lua"):format(name), true) > 0 then
      return name
    end
  end
end

local function typescript_init_options(root_dir)
  local init_options = {
    hostInfo = "neovim",
    preferences = {
      includeCompletionsForModuleExports = true,
      includeCompletionsForImportStatements = true,
      includeInlayEnumMemberValueHints = true,
      includeInlayFunctionLikeReturnTypeHints = true,
      includeInlayFunctionParameterTypeHints = true,
      includeInlayParameterNameHints = "all",
      includeInlayParameterNameHintsWhenArgumentMatchesName = false,
      includeInlayPropertyDeclarationTypeHints = true,
      includeInlayVariableTypeHints = true,
    },
  }

  local tsdk = root_dir and util.find_typescript_lib(root_dir) or nil

  if tsdk then
    init_options.tsdk = tsdk
  end

  return init_options
end

return {
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer" },
        }),
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local server_name = available_lsp_config({ "ts_ls", "tsserver" })

      if not server_name then
        vim.notify("typescript-language-server config was skipped because lspconfig has no ts_ls/tsserver entry.", vim.log.levels.WARN)
        return
      end

      vim.lsp.config(server_name, {
        capabilities = capabilities(),
        on_attach = on_attach,
        root_dir = function(bufnr, on_dir)
          on_dir(util.project_root(bufnr))
        end,
        cmd = function(dispatchers, config)
          local tsserver_bin = util.resolve_executable(config.root_dir, { "typescript-language-server" }) or "typescript-language-server"

          return vim.lsp.rpc.start({ tsserver_bin, "--stdio" }, dispatchers, {
            cwd = config.root_dir,
            detached = config.detached,
            env = config.cmd_env,
          })
        end,
        init_options = typescript_init_options(nil),
        before_init = function(params, config)
          local init_options = typescript_init_options(config.root_dir)

          config.init_options = init_options
          params.initializationOptions = init_options
        end,
      })

      if not vim.lsp.is_enabled(server_name) then
        vim.lsp.enable(server_name)
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        desc = "Format buffer",
      },
    },
    config = function()
      require("conform").setup({
        format_on_save = function(bufnr)
          local ft = vim.bo[bufnr].filetype

          if util.is_javascript_or_typescript(ft) then
            if #util.javascript_formatters(bufnr) == 0 then
              return nil
            end

            return {
              lsp_fallback = false,
              timeout_ms = 2000,
            }
          end

          return {
            lsp_fallback = true,
            timeout_ms = 2000,
          }
        end,
        formatters = {
          biome = {
            command = function(_, ctx)
              return util.resolve_executable(ctx.filename, { "biome" }) or "biome"
            end,
            condition = function(_, ctx)
              return util.has_biome_config(ctx.filename) and util.resolve_executable(ctx.filename, { "biome" }) ~= nil
            end,
          },
          prettier = {
            command = function(_, ctx)
              return util.resolve_executable(ctx.filename, { "prettier" }) or "prettier"
            end,
            condition = function(_, ctx)
              return util.has_prettier_config(ctx.filename) and util.resolve_executable(ctx.filename, { "prettier" }) ~= nil
            end,
          },
        },
        formatters_by_ft = {
          javascript = { "biome", "prettier", stop_after_first = true },
          javascriptreact = { "biome", "prettier", stop_after_first = true },
          json = { "biome", "prettier", stop_after_first = true },
          jsonc = { "biome", "prettier", stop_after_first = true },
          tsx = { "biome", "prettier", stop_after_first = true },
          typescript = { "biome", "prettier", stop_after_first = true },
          typescriptreact = { "biome", "prettier", stop_after_first = true },
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")
      local eslint_name
      local biome_name

      for _, name in ipairs({ "eslint_d", "eslint" }) do
        if lint.linters[name] then
          eslint_name = name
          break
        end
      end

      for _, name in ipairs({ "biomejs", "biome" }) do
        if lint.linters[name] then
          biome_name = name
          break
        end
      end

      if eslint_name then
        lint.linters.dotfiles_eslint = vim.deepcopy(lint.linters[eslint_name])
        lint.linters.dotfiles_eslint.cmd = function()
          return util.resolve_executable(vim.api.nvim_get_current_buf(), { "eslint_d", "eslint" }) or eslint_name
        end
      end

      if biome_name then
        lint.linters.dotfiles_biome = vim.deepcopy(lint.linters[biome_name])
        lint.linters.dotfiles_biome.cmd = function()
          return util.resolve_executable(vim.api.nvim_get_current_buf(), { "biome" }) or biome_name
        end
      end

      local group = vim.api.nvim_create_augroup("dotfiles_lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = group,
        callback = function(args)
          local names = {}

          if util.has_eslint_config(args.buf) and util.resolve_executable(args.buf, { "eslint_d", "eslint" }) and lint.linters.dotfiles_eslint then
            names[#names + 1] = "dotfiles_eslint"
          elseif util.has_biome_config(args.buf) and util.resolve_executable(args.buf, { "biome" }) and lint.linters.dotfiles_biome then
            names[#names + 1] = "dotfiles_biome"
          end

          if #names > 0 then
            lint.try_lint(names)
          end
        end,
      })
    end,
  },
}
