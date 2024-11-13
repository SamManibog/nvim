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
