---@type DirectorConfig
return {
    preserve = true,
    binds = {
        confirm =   { "<CR>", "<Space>" },
        edit =      { "i", "I", "a", "A" },
        new =       { "o", "O" },
        cancel =    { "<C-c>", "<Esc>" },
        up =        { "k", "<Up>" },
        down =      { "j", "<Down>" },
    },
    actions = {
        cargo = require("director.action_groups.cargo"),
        cmake = require("director.action_groups.cmake"),
    },
}
