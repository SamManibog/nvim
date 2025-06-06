return {
    { 
        "ellisonleao/gruvbox.nvim",
		lazy = false,
        priority = 1000,
        config = true,
        opts = {
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
            inverse = false, -- invert background for search, diffs, statuslines and errors
            contrast = "soft", -- can be "hard", "soft" or empty string
            palette_overrides = {},
            overrides = {},
            dim_inactive = false,
            transparent_mode = false,
        }
    },
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
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
