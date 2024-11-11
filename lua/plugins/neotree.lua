return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
        "MunifTanjim/nui.nvim",
        -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    lazy = false,
    config = function()
        require("neo-tree").setup({
            sort_case_insensitive = true,
            enable_git_status = true,
            filters = {
                git_ignored = true,
            },
            filesystem = {
                hijack_netrw_behavior = "disabled",
                filtered_items = {
                    visible = true,
                    show_hidden_count = true,
                    hide_dotfiles = false,
                    hide_gitignored = true,
                    hide_hidden = true,
                    hide_by_name = {
                        -- '.git',
                        -- '.DS_Store',
                        -- 'thumbs.db',
                    },
                }
            },
            git_status = {
                symbols = {
                    -- Change type
                    added     = "✚",
                    modified  = "",
                    deleted   = "🞬",
                    renamed   = "󰁕",
                    -- Status type
                    untracked = "",
                    ignored   = "",
                    unstaged  = "󰄱",
                    staged    = "",
                    conflict  = "",
                }
            },
        })
        vim.keymap.set({"n", "v"}, "<leader>pt", ":Neotree toggle<CR>")
    end
}
