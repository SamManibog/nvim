return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
    },
    lazy = false,
    config = function()
        require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities()
        )

        vim.lsp.config("lua_ls", {
            capabilities = capabilities,
            filetypes = { "lua" },
            settings = {
                Lua = {
                    runtime = { version = "Lua 5.1" },
                    diagnostics = {
                        globals = { "bit", "vim", "it", "describe", "before_each", "after_each" },
                    }
                }
            }
        })

        vim.lsp.config("rust_analyzer", {
            capabilities = capabilities,
        })

        vim.lsp.config("clangd", {
            capabilities = capabilities,
            cmd = {
                "clangd",
                "--query-driver=**",
                "--log=verbose",
                "--enable-config",
            },
            filetypes = {
                "c",
                "h",
                "cpp",
                "hpp",
                "objc",
                "objcpp",
                "cuda",
                "proto",
            }
        })

        vim.lsp.config("omnisharp", {
            capabilities = capabilities,
            cmd = {
                "dotnet",
                vim.fn.stdpath("data") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll"
            },
            enable_import_completion = true,
            organize_imports_on_format = true,
            enable_roslyn_analyzers = true,
            root_dir = function ()
                return vim.loop.cwd() -- current working directory
            end,
        })

        vim.lsp.config("wgsl_analyzer", {
            capabilities = capabilities,
        })

        require("mason").setup()
        require("mason-lspconfig").setup()
    end
}
