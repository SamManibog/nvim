local showing = false

vim.diagnostic.config({
    severity_sort = true
})

vim.api.nvim_create_autocmd("ModeChanged",
    {
        pattern = "*:n*",
        callback = function()
            vim.diagnostic.show(nil, 0)
        end
    }
)

vim.api.nvim_create_autocmd("ModeChanged",
    {
        pattern = "*:i*",
        callback = function()
            vim.diagnostic.hide(nil, 0)
        end
    }
)

vim.keymap.set("n", "<leader>d", function()
    if showing then
        vim.diagnostic.hide()
        vim.diagnostic.show()
    else
        vim.diagnostic.show(nil, nil, nil, {
            virtual_text = true
        })
    end
    showing = not showing
end)
