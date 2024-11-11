return {
    "j-hui/fidget.nvim",
    lazy = false,
    config = function()
        require("fidget").setup({})
        vim.diagnostic.config({
            -- update_in_insert = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

    end
}
