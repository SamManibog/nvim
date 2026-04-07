return {
    {
        "https://github.com/github/copilot.vim",
        lazy = false,
        config = function ()
            vim.keymap.set('i', '<C-Y>', 'copilot#Accept("\\<CR>")', {
                expr = true,
                replace_keycodes = false
            })
            vim.g.copilot_no_tab_map = true

            -- I only want chat functionality
            vim.cmd("Copilot disable")
        end,
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
            { "nvim-lua/plenary.nvim", branch = "master" },
        },
        -- build = "make tiktoken",
        config = function ()
            local chat = require("CopilotChat")

            chat.setup({
                model = 'gpt-4.1',
                temperature = 0.1,          -- Lower = focused, higher = creative
                window = {
                    layout = 'float',       -- 'vertical', 'horizontal', 'float'
                    width = 0.9,            -- 50% of screen width
                },
                auto_insert_mode = true,    -- Enter insert mode when opening
                mappings = {
                    close = {
                        callback = function (_)
                            require('CopilotChat').close()
                        end,
                        insert = "",
                        normal = "<C-c>",
                    },
                },
            })

            vim.api.nvim_create_autocmd('BufEnter', {
                pattern = 'copilot-*',
                callback = function()
                    vim.opt_local.relativenumber = false
                    vim.opt_local.number = false
                    vim.opt_local.conceallevel = 0
                end,
            })

            vim.keymap.set("n", "<leader>c", chat.open, { desc = "Open Copilot Chat" })
            vim.keymap.set("n", "<leader><leader>c", chat.reset, { desc = "Reset Copilot Chat" })
        end
    },
}
