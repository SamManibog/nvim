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
        local PreviewPopup = require("oneup.previewed_options_popup")
        PreviewPopup:new({
            preview_opts = {
                title = "preview",
                width = "40%",
                min_width = 10,
            },
            options_opts = {
                title = "options",
                width = "20%",
                min_width = 5
            },
            height = "20%",
            border = false,
            options = {
                {
                    text = "Option 1",
                    preview = { "Table-", "based", "text" }
                },
                {
                    text = "Option 2",
                    preview = function(self)
                        return {
                            self.text .. "'s",
                            "Function-",
                            "based",
                            "text"
                        }
                    end
                }
            }
        }, true)
    end,
    {
        nargs = 0,
        desc = "function for testing",
    }
)

