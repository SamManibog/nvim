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
        ["file action"] = {
            file_local = true,
            detect = function()
                return vim.fn.expand("%:p:e") == "cpp"
            end,
            actions = {
                {
                    bind = "cc",
                    desc = "cpp Hi Bound",
                    callback = function() print("Hi (bound)") end
                },
                {
                    desc = "cpp Hi",
                    callback = function() print("Hi") end
                },
            }
        }
    },
}
