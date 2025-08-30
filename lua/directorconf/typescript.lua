local utils = require("director.utils")

local terminal = "Typescript Watcher"

return {
    detect = function()
        utils.forceKillTerminal("Typescript Watcher")
        local detected = vim.fn.filereadable(vim.fn.getcwd().."/tsconfig.json") == 1;
        if detected then
            utils.runInTerminal("tsc --watch", terminal, true)
        end
        return detected
    end,
    actions = {
        {
            bind = "cc",
            desc = "Manual Compile",
            callback = function() utils.runInTerminal("tsc") end
        },
        {
            bind = "co",
            desc = "Open Auto Compile Terminal",
            callback = function()
                utils.openTerminal(terminal)
            end
        },
    }
}
