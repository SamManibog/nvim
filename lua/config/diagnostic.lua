---0 - show nothing
---1 - show signs, linting
---2 - show signs, linting, virtual text
---@type integer
local show_level = 1

vim.diagnostic.config({
    severity_sort = true
})

vim.api.nvim_create_autocmd("ModeChanged",
    {
        pattern = "*:n*",
        callback = function()
            if show_level >= 1 then
                vim.diagnostic.show(nil, 0)
            end
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
    show_level = show_level + 1
    if show_level > 2 then show_level = 0 end

    if show_level <= 0 then
        vim.diagnostic.hide()
    elseif show_level == 1 then
        vim.diagnostic.hide()
        vim.diagnostic.show()
    else
        vim.diagnostic.show(nil, nil, nil, {
            virtual_text = true
        })
    end
end)
