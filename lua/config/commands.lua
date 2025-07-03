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
        local popup = require("oneup.options_popup"):new(
            {
                title = "test",
                height = "60%",
                width = "60%",
                options = {
                    {
                        text = "title 1",
                        is_title = true
                    },
                    {
                        text = "test 1"
                    },
                    {
                        text = "title 2",
                        is_title = true
                    },
                    {
                        text = "test 2"
                    },
                    {
                        text = "test 3"
                    },
                }
            },
            true
        )
        popup:set_keymap("n", "j", function() popup:next_option() end)
        popup:set_keymap("n", "k", function() popup:prev_option() end)
        popup:set_keymap("n", "<CR>", function()
            print(popup:get_option().text)
            popup:close()
        end)
    end,
    {
        nargs = 0,
        desc = "function for testing",
    }
)

