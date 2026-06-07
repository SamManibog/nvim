return {
    "mbbill/undotree",
    lazy = false,
    config = function()
        vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
        if vim.fn.has('win32') == 1 then
            vim.g.undotree_DiffCommand = "FC"
        end
    end
}
