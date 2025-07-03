---@type DirectorConfig
return {
    preserve = true,
    config_types = {},
    binds = {
        confirm =   { "<CR>", "<Space>" },
        edit =      { "i", "I", "a", "A" },
        new =       { "o", "O" },
        cancel =    { "<C-c>", "<Esc>" },
    },
    cwd_actions = {},
    file_actions = {},
}
