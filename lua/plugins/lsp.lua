return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "folke/lazydev.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    lazy = false,
    config = function()
        vim.lsp.config("lua_ls", {
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

        vim.lsp.config("rust_analyzer", {})

        vim.lsp.config("clangd", {
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
            cmd = {
                "dotnet",
                vim.fn.stdpath("data") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll"
            },
            enable_import_completion = true,
            organize_imports_on_format = true,
            enable_roslyn_analyzers = true,
            root_dir = function()
                return vim.loop.cwd() -- current working directory
            end,
        })

        vim.lsp.config("wgsl_analyzer", {})

        require("mason").setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗"
                }
            }
        })
        require("mason-lspconfig").setup()
    end
}
