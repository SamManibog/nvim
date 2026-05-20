return {
    "nvim-treesitter/nvim-treesitter",
    branch = 'main',
    lazy = false,
    config = function()
        vim.api.nvim_create_autocmd('FileType', {
            callback = function()
                -- Enable treesitter highlighting and disable regex syntax
                pcall(vim.treesitter.start)
                -- Enable treesitter-based indentation
                vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end,
        })
        local ensureInstalled = {
            -- low-level
            "c",
            "cpp",
            "rust",

            -- scripting
            "lua",
            "python",

            -- vim
            "vim",
            "vimdoc",
            "query",

            -- markdown
            "markdown",
            "markdown_inline",

            -- web
            "json",
            "javascript",
            "typescript",
            "css",
            "html",
        }
        local alreadyInstalled = require('nvim-treesitter.config').get_installed()
        local parsersToInstall = vim.iter(ensureInstalled)
            :filter(function(parser)
                return not vim.tbl_contains(alreadyInstalled, parser)
            end)
            :totable()
        require('nvim-treesitter').install(parsersToInstall)
    end
}
