return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "folke/lazydev.nvim",
        "williamboman/mason.nvim",
        --"williamboman/mason-lspconfig.nvim",
    },
    lazy = false,
    config = function()
        vim.lsp.set_log_level("off")

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
        vim.lsp.enable("lua_ls")

        vim.lsp.config("rust_analyzer", {})
        vim.lsp.enable("rust_analyzer")

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
        vim.lsp.enable("clangd")

        vim.lsp.config("tsserver", {
            cmd = {
                "typescript-language-server",
                "--stdio",
            },
            filetypes = {
                "typescript",
                "typescriptreact",
                "typescript.tsx"
            },
            root_markers = { "tsconfig.json" },
        })
        vim.lsp.enable("tsserver")

        vim.lsp.config("omnisharp", {
            cmd = {
                "dotnet",
                vim.fn.stdpath("data") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll",
                "--languageserver"
            },
            filetypes = { "cs" },
            root_markers = { ".csproj" },
            --[[
            enable_import_completion = true,
            organize_imports_on_format = true,
            enable_roslyn_analyzers = true,
            ]]
        })
        vim.lsp.enable("omnisharp")

        vim.lsp.config("omnisharp-mono", {
            cmd = {
                "omnisharp-mono",
                "--languageserver",
            },
            filetypes = { "cs" },
            root_markers = { ".csproj" },
        })
        --vim.lsp.enable("omnisharp-mono")

        vim.lsp.config("eslint", {
            cmd = {
                "vscode-eslint-language-server",
                "--stdio"
            },
            filetypes = {
                "typescript",
                "typescriptreact",
                "typescript.tsx",
                "javascript",
                "javascriptreact",
                "javascript.jsx",
            },
            root_markers = {
                "eslint.config.js",
                "eslint.config.mjs",
                "eslint.config.cjs",
                "eslint.config.ts",
                "eslint.config.mts",
                "eslint.config.cts",
            }
        })
        vim.lsp.enable("eslint")

        require("mason").setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗"
                }
            }
        })
        --require("mason-lspconfig").setup()
    end
}
