local utils = require("config.utils")

vim.api.nvim_create_autocmd(
    "DirChanged",
    {
        pattern = "global",
        callback = utils.refreshBuildsystem
    }
)
