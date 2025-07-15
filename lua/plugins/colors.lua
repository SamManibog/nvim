return {
    {
        "ellisonleao/gruvbox.nvim",
		lazy = false,
        priority = 1000,
        config = function()
            require("gruvbox").setup({
                terminal_colors = true, -- add neovim terminal colors
                undercurl = true,
                underline = true,
                bold = true,
                italic = {
                    strings = false,
                    emphasis = true,
                    comments = true,
                    operators = false,
                    folds = true,
                },
                strikethrough = true,
                invert_selection = false,
                invert_signs = false,
                invert_tabline = false,
                inverse = true, -- invert background for search, diffs, statuslines and errors
                contrast = "soft", -- can be "hard", "soft" or empty string
                palette_overrides = {},
                overrides = {
                    ["@namespace"] = { link = "Type" }
                },
                dim_inactive = false,
                transparent_mode = false,
            })
        end
    },
	{
		"rebelot/kanagawa.nvim",
		lazy = true,
		priority = 1000,
		config = function()
			require('kanagawa').setup({
                theme = "dragon",
				background = {
                    light = "lotus",
					dark = "dragon",
				}
			})
		end,
	},
}
