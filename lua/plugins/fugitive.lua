return {
    "tpope/vim-fugitive",
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>gs", function()
            vim.cmd("tab split")
            vim.cmd("Git")
            local git_win = vim.fn.win_getid()
            local sibling_ids = vim.api.nvim_tabpage_list_wins(0)
            for _, id in pairs(sibling_ids) do
                if id ~= git_win then
                    vim.api.nvim_win_close(id, false)
                end
            end
        end)
    end
}
