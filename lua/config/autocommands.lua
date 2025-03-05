local bs = require("config.buildsystems")

vim.api.nvim_create_autocmd(
    'DirChanged',
    {
        pattern = 'global',
        callback = bs.refreshBuildSystem
    }
)
vim.api.nvim_create_autocmd(
    'VimEnter',
    {
        callback = bs.refreshBuildSystem
    }
)
