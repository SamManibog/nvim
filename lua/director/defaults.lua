---@type DirectorConfig
---@diagnostic disable-next-line:missing-fields
return {
    preserve = true,
    binds = {
        new =               { "o", "O", "n", "N" },
        rename =            { "r", "R" },
        delete =            { "d", "D" },
        select =            { "<CR>", "<Space>" },
        edit =              { "e", "E" },
        cancel =            { "<C-c>", "<Esc>" },
        up =                { "k", "<Up>" },
        down =              { "j", "<Down>" },
        quick_menu =        {},
        directory_menu =    {},
        file_menu =         {},
        main_menu =         {},
        config_menu =       {},
    },
    actions = {
        cargo = require("director.action_groups.cargo"),
        cmake = require("director.action_groups.cmake"),
        ["file action"] = {
            file_local = true,
            detect = function()
                return vim.fn.expand("%:p:e") == "cpp"
            end,
            actions = {
                {
                    bind = "cc",
                    desc = "cpp Hi Bound",
                    callback = function() print("Hi (bound)") end
                },
                {
                    desc = "cpp Hi",
                    callback = function() print("Hi") end
                },
                {
                    bind = "t",
                    desc = "test",
                    configs = { "test1" },
                    callback = function(data)
                        local test1 = data.test1
                        print("String: "..test1["config string"])
                        print("Number: "..test1["config number"])
                        print("Bool: "..tostring(test1["config boolean"]))
                        print("Option: "..test1["config option"])
                        print("List values:")
                        for _, val in ipairs(test1["config list"]) do
                            print("\t"..val)
                        end
                    end
                }
            },
            config_types = {
                test1 = {
                    {
                        name = "config string",
                        type = "string",
                        default = "default",
                        validate = function(str)
                            if string.sub(str, 1, 1) == "d" then
                                return true
                            else
                                print("value must begin with 'd'")
                                return false
                            end
                        end
                    },
                    {
                        name = "config number",
                        type = "number",
                        default = 0,
                    },
                    {
                        name = "config boolean",
                        type = "boolean",
                        default = true,
                    },
                    {
                        name = "config option",
                        type = "option",
                        default = function()
                            return {
                                "default option",
                                "hello",
                                "hi",
                                "cool",
                            }
                        end
                    },
                    {
                        name = "config list",
                        type = "list",
                        default = {
                            "all",
                            "ant",
                            "avid"
                        },
                        validate = function(list)
                            for _, str in pairs(list) do
                                if string.sub(str, 1, 1) ~= "a" then
                                    print("values must begin with a")
                                    return false
                                end
                            end
                            return true
                        end
                    }
                }
            },
        }
    },
}
