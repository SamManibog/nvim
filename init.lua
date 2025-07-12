require("config.lazy")
require("config.remap")
require("config.set")
require("config.commands")

require("config.propicker")
require("director").setup({
    binds = {
        quick_menu = "<leader>b",
        main_menu = "<leader>mm",
        config_menu = "<leader>mc",
    }
})

-- Set colorscheme
vim.cmd.colorscheme("gruvbox")
