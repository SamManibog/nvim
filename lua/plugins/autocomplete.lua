return {
    'saghen/blink.cmp',
    dependencies = {
        "folke/lazydev.nvim",
        --'rafamadriz/friendly-snippets',
        "L3MON4D3/LuaSnip",
    },

    -- use a release tag to download pre-built binaries
    version = '1.*',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {

        keymap = {
            ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
            ['<C-y>'] = { 'select_and_accept', 'fallback' },
            ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
            ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },
            ['<Tab>'] = {},
            ['<S-Tab>'] = {},
            -- ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
            -- ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
            -- ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
        },

        appearance = {
            nerd_font_variant = 'mono'
        },

        completion = { documentation = { auto_show = true } },

        snippets = { preset = "luasnip" },

        sources = {
            default = { "lazydev", "lsp", "path", "snippets", "buffer" },
            providers = {
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    -- make lazydev completions top priority (see `:h blink.cmp`)
                    score_offset = 100,
                }
            },
        },

        fuzzy = { implementation = "prefer_rust_with_warning" }
    },
    opts_extend = { "sources.default" }
}
