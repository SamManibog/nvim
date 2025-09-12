return {
    "SamManibog/director",
    dependencies = { "SamManibog/oneup" },
    lazy = false,
    config = function()
        require("director").setup({
            disk_saves = true,
            binds = {
                quick_menu = "<leader>b",
                main_menu = "<leader>mm",
                config_menu = "<leader>mc",
            },
            actions = {
                cmake = require("directorconf.cmake"),
                cargo = require("directorconf.cargo"),
                typescript = require("directorconf.typescript"),
                globals = require("directorconf.global"),
            }
        })
    end
}
