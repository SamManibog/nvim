vim.api.nvim_create_user_command(
    "Light",
    function (_)
        vim.cmd("set background=light")
    end,
    {
        nargs = 0,
        desc = "sets colors to light theme",
    }
)

vim.api.nvim_create_user_command(
    "Dark",
    function (_)
        vim.cmd("set background=dark")
    end,
    {
        nargs = 0,
        desc = "sets colors to dark theme",
    }
)
