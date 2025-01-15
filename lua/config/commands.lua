local utils = require("config.utils")

vim.api.nvim_create_user_command(
    "Light",
    function (_)
        vim.cmd("colo kanagawa-lotus")
    end,
    {
        nargs = 0,
        desc = "sets colors to light theme",
    }
)

vim.api.nvim_create_user_command(
    "Dark",
    function (_)
        vim.cmd("colo kanagawa-dragon")
    end,
    {
        nargs = 0,
        desc = "sets colors to dark theme",
    }
)

vim.api.nvim_create_user_command(
    "AsyncCall",
    function (data)
        vim.cmd("tabnew")
        vim.cmd("terminal " .. data.args .. "&& exit")
        vim.cmd("q")
    end,
    {
        nargs = '+',
        desc = "Asynchronously runs a command from the terminal",
    }
)

vim.api.nvim_create_user_command(
    "Ob",
    function(data)
        local bufs = vim.api.nvim_list_bufs()
        vim.cmd("tabnew")
        local index = tonumber(data.args)
        vim.cmd("b " .. bufs[index])
    end,
    {
        nargs = 1,
        desc = "Opens the buffer with the given index in a new tab",
    }
)

vim.api.nvim_create_user_command(
    "Fileexplorer",
    function(_)
        os.execute("Explorer.exe " .. vim.fn.getcwd())
    end,
    {
        nargs = 0,
        desc = "Opens the windows file explorer on the current root",
    }
)

--[[
vim.api.nvim_create_user_command(
    "Run",
    function(args)
        utils.runFile(args)
    end,
    {
        nargs = '*',
        desc = "Attempts to run the current file or project or file"
        .. " precedence is given to the current file"
    }
)
]]
