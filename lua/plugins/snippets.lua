return {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    lazy = false,
    config = function()
        local ls = require("luasnip")
        require("luasnip.loaders.from_vscode").lazy_load()
        --require("luasnip.loaders.from_lua").load({ paths = vim.fn.stdpath("config").."/snippets" })
        --require("luasnip.loaders.from_lua").load({ paths = "~/snippets" })
        require("luasnip.loaders.from_lua").load({ paths = vim.fn.stdpath("config").."/lua/snippets" })

        --expand or jump with tab
        vim.keymap.set({"i"}, "<Tab>", function()
            if ls.expand_or_jumpable() then
                ls.expand_or_jump()
            else
                vim.api.nvim_put({"\t"}, "c", false, true)
            end
        end, { silent = true, remap = true })
        vim.keymap.set({"i", "s"}, "<S-Tab>", function() ls.jump(-1) end, { silent = true })

        vim.keymap.set({"i", "s"}, "<C-E>", function()
            if ls.choice_active() then
                ls.change_choice(1)
            end
        end, { silent = true })
    end
}
