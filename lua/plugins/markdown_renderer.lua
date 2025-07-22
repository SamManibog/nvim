return {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ft = { 'markdown', 'quarto' },
    completions = { blink = { enabled = true } },

    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
        render_modes = true,
    },
}
