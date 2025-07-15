require("config.lazy")
require("config.set")
require("config.remap")
require("config.commands")
require("config.diagnostic")

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
