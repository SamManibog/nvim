local utils = require("director.utils")

return {
    detect = function() return true end,
    actions = {
        {
            desc = "ESlint QuickStart",
            callback = function()
                if vim.fn.filereadable(vim.fn.getcwd().."/package.json") == 0 then
                    utils.runInTerminal("npm init && npm init @eslint/config@latest")
                else
                    utils.runInTerminal("npm init @eslint/config@latest")
                end
            end
        },
    }
}
