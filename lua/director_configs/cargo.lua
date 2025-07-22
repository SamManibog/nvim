local utils = require("director.utils")

---@type ActionGroup
return {
    detect = function()
        return vim.fn.filereadable(vim.fn.getcwd().. "/Cargo.toml") == 1
    end,
    actions = {
        {
            bind = "cc",
            desc = "Compile",
            callback = function() utils.runInTerminal("cargo build") end
        },
        {
            bind = "r",
            desc = "Run",
            callback = function() utils.runInTerminal("cargo run") end
        },
    }
}
