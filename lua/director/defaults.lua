---@type DirectorConfig
return {
    disk_saves = true,
    binds = {
        new =               { "o", "O", "n", "N" },
        rename =            { "r", "R" },
        delete =            { "d", "D" },
        select =            { "<CR>", "<Space>" },
        edit =              { "e", "E", "i", "I", "a", "A" },
        cancel =            { "<C-c>", "<Esc>" },
        up =                { "k", "<Up>" },
        down =              { "j", "<Down>" },
        quick_menu =        {},
        directory_menu =    {},
        file_menu =         {},
        main_menu =         {},
        config_menu =       {},
    },
    actions = {}
}
