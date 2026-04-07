return {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    lazy = false,
    config = function()
        local ls = require("luasnip")
        require("luasnip.loaders.from_vscode").lazy_load()
        require("luasnip.loaders.from_lua").load({ paths = vim.fn.stdpath("config").."/lua/snippets" })

        -- expand or jump
        vim.keymap.set({"n", "i"}, "<C-L>", function() ls.expand_or_jump() end, { silent = true, remap = true })
        vim.keymap.set({"n", "i", "s"}, "<C-H>", function() ls.jump(-1) end, { silent = true })

        -- select choice
        vim.keymap.set({"i", "s"}, "<C-E>", function()
            if ls.choice_active() then
                ls.change_choice(1)
            end
        end, { silent = true })

        -- clear snippets in buffer
        vim.keymap.set({"n"}, "<leader><C-E>", function()
            ls.session.current_nodes[vim.api.nvim_get_current_buf()] = nil
            print("cleared snippets in current buffer")
        end, { silent = true })
    end
}
