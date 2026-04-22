return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    priority = 1000,
    opts = {
      options = {
        transparent = false,
        hide_end_of_buffer = true,
        darken = {
          floats = false,
          sidebars = {
            enable = false,
          },
        },
        styles = {
          comments = "italic",
        },
      },
      groups = {
        all = {
          Normal = { bg = "#ffffff" },
          NormalNC = { bg = "#ffffff" },
          SignColumn = { bg = "#ffffff" },
          LineNr = { bg = "#ffffff", fg = "#9ca3af" },
          CursorLineNr = { bg = "#ffffff", fg = "#4b5563", bold = true },
          EndOfBuffer = { bg = "#ffffff", fg = "#d0d7de" },
          NormalFloat = { bg = "#f6f8fa" },
          FloatBorder = { bg = "#f6f8fa", fg = "#d0d7de" },
          Pmenu = { bg = "#f6f8fa" },
          PmenuSel = { bg = "#dbeafe", fg = "#1f2937" },
          CursorLine = { bg = "#f8fafc" },
          ColorColumn = { bg = "#f3f4f6" },
          NeoTreeNormal = { bg = "#f8fafc" },
          NeoTreeNormalNC = { bg = "#f8fafc" },
          StatusLine = { bg = "#f6f8fa" },
          StatusLineNC = { bg = "#f8fafc" },
          WinSeparator = { fg = "#d0d7de" },
        },
      },
    },
    config = function(_, opts)
      vim.opt.background = "light"

      require("github-theme").setup(opts)
      vim.cmd.colorscheme("github_light_default")
    end,
  },
}
