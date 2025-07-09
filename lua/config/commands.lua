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

vim.api.nvim_create_user_command(
    "Test",
    function(_)
        require("oneup.config_popup"):new({
            fields = {
                string = {
                    type = "string"
                },
                number = {
                    type = "number"
                },
                boolean = {
                    type = "boolean"
                },
                option = {
                    type = "option"
                },
                string_list = {
                    type = "string list"
                },
                number_list = {
                    type = "number list"
                },
                boolean_list = {
                    type = "boolean list"
                }
            },
            big_input_opts = {
                width = "40%",
                height = "40%"
            },
            small_input_width = "20%",
            preview_opts = {
                width = "40%",
                height = "40%"
            },
            options_opts = {
                width = "40%",
                height = "40%"
            },
            height = "40%",
            config = {
                string = "default str",
                number = 7,
                boolean = true,
                option = "first option",
                string_list = { "hi1", "hi2", "hi3" },
                number_list = { 1, 2, 3, 4, 5 },
                boolean_list = { true, false, true, false }
            },
            next_bind = { "j", "<Down>" },
            previous_bind = { "k", "<Up>" },
            close_bind = { "<Esc>", "<C-c>" },
        }, true)
    end,
    {
        nargs = 0,
        desc = "function for testing",
    }
)

