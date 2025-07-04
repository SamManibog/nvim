local utils = require("director.utils")

---@type ActionGroup
return {
    detect = utils.detectCargo,
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
