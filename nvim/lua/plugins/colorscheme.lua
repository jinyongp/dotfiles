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
          comments = "NONE",
          functions = "NONE",
          keywords = "NONE",
          variables = "NONE",
          conditionals = "NONE",
          constants = "NONE",
          numbers = "NONE",
          operators = "NONE",
          strings = "NONE",
          types = "NONE",
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

          Comment = { fg = "#57606a", style = "NONE" },
          ["@comment"] = { fg = "#57606a", style = "NONE" },
          ["@comment.documentation"] = { fg = "#57606a", style = "NONE" },

          Keyword = { fg = "#cf222e", style = "italic" },
          Statement = { fg = "#cf222e", style = "italic" },
          Conditional = { fg = "#cf222e", style = "italic" },
          Repeat = { fg = "#cf222e", style = "italic" },
          Exception = { fg = "#cf222e", style = "italic" },
          ["@keyword"] = { fg = "#cf222e", style = "italic" },
          ["@keyword.function"] = { fg = "#cf222e", style = "italic" },
          ["@keyword.return"] = { fg = "#cf222e", style = "italic" },
          ["@keyword.import"] = { fg = "#cf222e", style = "italic" },
          ["@keyword.operator"] = { fg = "#cf222e", style = "italic" },

          Operator = { fg = "#0550ae", style = "NONE" },
          ["@operator"] = { fg = "#0550ae", style = "NONE" },

          Boolean = { fg = "#116329", style = "italic" },
          ["@boolean"] = { fg = "#116329", style = "italic" },
          ["@constant.builtin"] = { fg = "#116329", style = "italic" },
          ["@type.builtin"] = { fg = "#116329", style = "italic" },

          htmlTag = { fg = "#116329", style = "italic" },
          xmlTagName = { fg = "#116329", style = "italic" },
          ["@tag"] = { fg = "#116329", style = "italic" },

          xmlAttrib = { fg = "#0550ae", style = "italic" },
          htmlArg = { fg = "#0550ae", style = "italic" },
          ["@tag.attribute"] = { fg = "#0550ae", style = "italic" },
          ["@attribute"] = { fg = "#0550ae", style = "italic" },

          ["@constructor"] = { fg = "#953800", style = "italic" },
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
