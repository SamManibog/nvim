return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    lazy = false,
    config = function()
        local builtin = require('telescope.builtin')

        --setting search path
        local search_dir = nil
        do
            local first_file = vim.fn.argv()[1]

            if first_file ~= nil then
                local first_entry = vim.uv.fs_stat(first_file)
                if first_entry ~= nil and first_entry.type == "directory" then
                    search_dir = first_file
                end
            end
        end

        --whether to set hidden flag (disable for windows)
        ---@type boolean?
        local hidden = true
        if vim.fn.has("windows") then
            hidden = nil
        end

        vim.keymap.set('n', '<leader>pf', function()
            local dir = search_dir or vim.fn.getcwd()
            builtin.find_files({
                cwd = dir,
                hidden = hidden,
            })
        end)
        vim.keymap.set('n', '<leader>pg', builtin.git_files, {})
        vim.keymap.set('n', '<leader>ps', function()
            builtin.grep_string({search = vim.fn.input("Grep > ")})
        end)
    end
}
