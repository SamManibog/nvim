require("config.lazy")
require("config.set")
require("config.remap")
require("config.commands")
require("config.diagnostic")

require("config.propicker")
require("director").setup({
    disk_saves = true,
    binds = {
        quick_menu = "<leader>b",
        main_menu = "<leader>mm",
        config_menu = "<leader>mc",
    },
    actions = {
        cmake = require("director_configs.cmake"),
        cargo = require("director_configs.cargo"),
    }
})

-- Set colorscheme
vim.cmd.colorscheme("gruvbox")

