return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim"
    },
    lazy = false,
    config = function()
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>pf', function()
            local search_dir = nil
            local first_file = vim.fn.argv()[1]

            if first_file ~= nil then
                local first_entry = vim.uv.fs_stat(first_file)
                if first_entry ~= nil and first_entry.type == "directory" then
                    search_dir = first_file
                end
            end

            builtin.find_files({
                cwd = search_dir,
                hidden = true,
            })
        end)
        vim.keymap.set('n', '<leader>pg', builtin.git_files, {})
        vim.keymap.set('n', '<leader>ps', function()
            builtin.grep_string({search = vim.fn.input("Grep > ")})
        end)
    end
}
