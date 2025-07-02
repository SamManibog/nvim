local M = {}

local OptionsPopup = require("oneup.options_popup")
local utils = require("config.utils")

----------------------------------------------------------------
--utils
----------------------------------------------------------------
---creates a directory at the given path if it doesn't already exist
---@param path string the path at which to make the directory (no parents created)
local function mkdir(path)
    if not vim.fn.isdirectory(path) then
        vim.uv.fs_mkdir(path, tonumber("777", 8))
    end
end

---@class ActionDescriptor
---@field bind string                   the keybinding for the action
---@field desc string                   the displayed discription of the action
---@field callback fun(data: table?)    the function to call when the action is used
---@field configure_type string?        the configuration type of the action valid options are defined by action_types in config
---@field detect (fun(): boolean)?      the function ran to detect if the action is available (always available if nil)
---@field priority number?              if keybinds conflict, the action with the higher priority is used (default 0)

---@class ActionConfigField
---@field name string                                   the name of the field
---@field is_list boolean?                              whether or not the field is a list or a string
---@field default (fun(): string[]) | string[] | nil    function to get the default value of the field when creating a new config

---@class DirectorBindsConfig
---@field confirm string[]      a list of binds used to confirm a selection
---@field edit string[]        a list of binds used to edit a given field
---@field new_config string[]   a list of binds used to create a new action configuration
---@field cancel string[]       a list of binds used to return to the previous menu (or close the menu)

---@class DirectorConfig
---@field preserve boolean                              whether or not to save in-editor configuration to disk
---@field action_types {[string]: ActionConfigField[]}  a dictionary of action_types which may be configured in-editor
---@field binds DirectorBindsConfig                     binds for menus
---@field actions ActionDescriptor[]                    a list of action descriptors that may be used

-- action configuration
local actionsData = {}

-- list of actions
local actions = {}

---@type DirectorConfig
local default = {
    preserve = true,
    action_types = {
        execute = {
            {
                name = "path",
                default = function()
                    return { vim.fn.expand("%:p") }
                end
            },
            {
                name = "args",
                is_list = true
            }
        },
        compile = {
            {
                name = "target"
            },
            {
                name = "args",
                is_list = true
            }
        },
        ctest = {
            {
                name = "target"
            },
            {
                name = "tester args",
                is_list = true
            },
            {
                name = "exec args",
                is_list = true
            }
        }
    },
    binds = {
        confirm = { "<CR>", "<Space>" },
        edit = { "<C-e>" },
        new_config = { "i", "I", "a", "A", "o", "O" },
        cancel = { "<C-c>", "<Esc>" },
    },
    actions = {}
}

---@type DirectorConfig
local config

---setup the plugin
---@param opts table
function M.setup(opts)
    ---@type DirectorConfig
    config = vim.tbl_deep_extend('force', default, opts or {})

    vim.api.nvim_create_autocmd(
        'DirChanged',
        {
            pattern = 'global',
            callback = M.refreshActions,
        }
    )

    vim.api.nvim_create_autocmd(
        'VimEnter',
        {
            callback =  M.refreshActions,
        }
    )

end

---saves the data for the given action bind
---@param bind string
local function saveActionsData(bind)
    if actionsData[bind] == nil then return end

    ---@type string
    local dataPath = vim.fn.stdpath("data") .. "/director"

    ---@type string
    local manifestPath = dataPath .. "/manifest.json"

    ---@type string
    local folderName = vim.fn.json_decode(vim.fn.readfile(manifestPath))[vim.fn.getcwd()]

    ---@type string
    local bindPath = dataPath .. "/" .. folderName .. "/" .. bind .. ".json"

    ---@type file*?
    local bindFile = io.open(bindPath, "w")
    if bindFile ~= nil then
        bindFile:write(vim.fn.json_encode(actionsData[bind]))
        bindFile:close()
    else
        print("unable to write to file: " .. bindPath)
    end
end

---loads action data for the given directory and binds into memory (actionsData variable),
---writing files to disk if necessary
---@param configure_types string[] a list of all configuration types that must be loaded
local function loadActionsData(configure_types)
    --exit early if there is no data to load
    do
        local _, v = next(configure_types)
        if v == nil then return end
    end

    actionsData = {}

    if not config.preserve then
        for _, config_type in pairs(configure_types) do
            actionsData[config_type] = {
                actions = {}
            }
        end
        return
    end

    ---@type string the cwd path
    local path = vim.fn.getcwd()

    --read/write to manifest file
    ---@type string
    local dataPath = vim.fn.stdpath("data") .. "/director"

    ---@type string
    local manifestPath = dataPath .. "/manifest.json"

    ---@type string
    local folderName

    --check if manifest file exists
    if vim.fn.filereadable(manifestPath) == true then
        local manifest = vim.fn.json_decode(vim.fn.readfile(manifestPath))

        --if directory is not in the manifest, add it to the manifest
        if manifest[path] == nil then
            --determine a suitable name for the data folder
            local folder = 0
            while true do
                if not vim.fn.isdirectory(dataPath .. tostring(folder)) then
                    folderName = tostring(folder)
                    manifest[path] = folderName
                    break
                end
                folder = folder + 1
            end

            --write the updated data to the manifest file
            local manifestFile = io.open(manifestPath, "w")
            if manifestFile ~= nil then
                manifestFile:write(vim.fn.json_encode(manifest))
                manifestFile:close()
            else
                print("unable to write to file: " .. manifestPath)
            end
        else
            --if the directory is in the manifest, we know the folder name
            folderName = manifest[path]
        end

    else

        --if manifest file does not exist, create a new one
        mkdir(dataPath)
        local manifestFile = io.open(manifestPath, "w")
        if manifestFile ~= nil then
            manifestFile:write(vim.fn.json_encode({
                [path] = "0"
            }))
            manifestFile:close()
        else
            print("unable to write to file: " .. manifestPath)
        end

        folderName = "0"
    end

    --ensure the actionsPath exists
    local actionsPath = dataPath .. "/" .. folderName
    mkdir(actionsPath)

    --for action data of each type...
    for _, config_type in pairs(configure_types) do
        local typePath = actionsPath .. "/" .. config_type .. ".json"

        --check if data is readable
        if vim.fn.filereadable(typePath) then
            --read the file into memory
            actionsData[typePath] = vim.fn.json_decode(vim.fn.readfile(typePath))

        else
            --if data is not readable, create a new file
            local bindFile = io.open(typePath, "w")
            if bindFile ~= nil then
                bindFile:write(vim.fn.json_encode({
                    actions = {}
                }))
                bindFile:close()
            else
                print("unable to write to file: " .. typePath)
            end

            actionsData[config_type] = { actions = {} }
        end
    end
end

---adds or edits an action configuration for the given bind
---@param bind string the bind of action to add a config for
---@param label string the label for the action
---@param data table the configuration to store
function M.makeActionConfig(bind, label, data)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    actionsData[bind].actions[label] = data

    if config.preserve then
        saveActionsData(bind)
    end
end

---removes an action configuration for the given bind
---@param bind string the bind at which to remove a configuration
---@param label string the label of the action config to remove
function M.removeActionConfig(bind, label)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    actionsData[bind].actions[label] = nil

    if config.preserve then
        saveActionsData(bind)
    end
end

---sets the current action config for the given bind 
---@param bind string the bind of action to set
---@param label string the label of the action to set
function M.setActionConfig(bind, label)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    if actionsData[bind][label] == nil then
        error("Action bind '" .. bind .. "' does not have a config '" .. label "'")
    end

    actionsData[bind].current = label

    if config.preserve then
        saveActionsData(bind)
    end
end

function M.refreshActions()
    --detect and load actions
    ---@type { [string]: ActionDescriptor }
    actions = {}
    for _, action in pairs(config.actions) do
        --check if the action should exist for the current directory
        if action.detect() then
            local actionPriority = action.priority or 0

            local existingPriority = -1
            if actions[action.bind] ~= nil then
                existingPriority = actions[action.bind].priority or 0
            end

            --only add the action with the highest priority for the same bind
            if existingPriority < actionPriority then
                actions[action.bind] = action
            end
        end
    end

    --load all relevant action config data
    ---@type string[]
    local configure_types = {}
    for _, action in pairs(actions) do
        if action.configure_type ~= nil then
            table.insert(configure_types, action.configure_type)
        end
    end
    loadActionsData(configure_types)
end

function M.actionsMenu()
    do
        local _, v = next(actions)
        if v == nil then
            print("No actions are valid for this directory.")
            return
        end
    end

    --perform calculations for bind annotations
    local maxBindLength = 0
    local hyphen = ""
    for _, action in pairs(actions) do
        if action.bind == nil then break end
        maxBindLength = math.max(maxBindLength, #action.bind)
    end

    if maxBindLength > 0 then hyphen = " - " end

    ---@type { callback: function, bind: string }[]
    local bindedActions = {}
    ---@type Option[]
    local actionOptions = {}
    for _, action in pairs(actions) do
        ---@type function
        local callback

        if action.configurable then
            callback = function()
                action.callback(actionsData[action.bind].actions[actionsData[action.bind].current])
            end
        else
            callback = action.callback
        end

        local text
        if action.bind == nil then
            text = string.rep(" ", maxBindLength) .. hyphen .. action.desc
        else
            text = string.rep(" ", maxBindLength - #action.bind) .. action.bind .. hyphen .. action.desc

            table.insert(bindedActions, {
                bind = action.bind,
                callback = callback
            })
        end

        table.insert(actionOptions, {
            text = text,
            callback = callback
        })
    end

    local menu = OptionsPopup(
        {
            title = "Actions",
            min_width = 20,
            border = true,
            closeBinds = config.binds.cancel,
            selectBinds = config.binds.confirm,
            options = actionOptions
        },
        true
    )

    for _, bind in pairs(config.binds.confirm) do
        menu:set_keymap("n", bind, function()
            menu:get_option().callback()
        end)
    end

    for _, bind in pairs(config.binds.cancel) do
        menu:set_keymap("n", bind, function() menu:close() end)
    end

    for _, binded in pairs(bindedActions) do
        menu:set_keymap("n", binded.bind, binded.callback)
    end

end

function M.actionConfigMenu()
    do
        local _, v = next(actionsData)
        if v == nil then
            print("No actions are configurable in this directory.")
            return
        end
    end


end

local function detectCmake()
    return vim.fn.filereadable(vim.fn.getcwd().."/CMakeLists.txt") == 1
end
local function detectCargo()
    return vim.fn.filereadable(vim.fn.getcwd().. "/Cargo.toml") == 1
end

M.setup({
    ---@type ActionDescriptor[]
    actions = {
        --cargo buildsystem
        {
            bind = "cc",
            desc = "Compile",
            detect = detectCargo,
            callback = function() utils.runInTerminal("cargo build") end
        },
        {
            bind = "r",
            desc = "Run",
            detect = detectCargo,
            callback = function() utils.runInTerminal("cargo run") end
        },

        --cmake buildsystem
        {
            bind = "cc",
            desc = "Compile",
            detect = detectCmake,
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build")
            end
        },
        {
            bind = "b",
            desc = "Build",
            detect = detectCmake,
            callback = function ()
                if utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_rmdir(vim.fn.getcwd().."/build")
                end
                utils.runInTerminal("cmake --preset=debug -B build -S .")
            end
        },
        {
            bind = "r",
            desc = "Run",
            detect = detectCmake,
            callback = function ()
                utils.runInTerminal("\"./build/main.exe\"")
            end
        },
        {
            bind = "cr",
            desc = "Compile and Run",
            detect = detectCmake,
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && \"./build/main.exe\"")
            end
        },
        {
            bind = "ts",
            desc = "Test (Silent)",
            detect = detectCmake,
            callback = function ()
                utils.runInTerminal("cd build && ctest")
            end
        },
        {
            bind = "tl",
            desc = "Test (Verbose)",
            detect = detectCmake,
            callback = function ()
                utils.runInTerminal("cd build && ctest --verbose")
            end
        },
        {
            bind = "cts",
            desc = "Compile and Test (Silent)",
            detect = detectCmake,
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && cd build && ctest")
            end
        },
        {
            bind = "ctl",
            desc = "Compile and Test (Verbose)",
            detect = detectCmake,
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && cd build && ctest --verbose")
            end
        },
        {
            bind = "I",
            desc = "Install as Package",
            detect = detectCmake,
            callback = function ()
                local package_folder = os.getenv("CMakePackagePath")
                if package_folder == nil then
                    print("CMakePackagePath environment variable must be set")
                end
                if utils.isDirectoryEntry(package_folder) then
                    if utils.isDirectory(vim.fn.getcwd().."/build") then
                        vim.uv.fs_rmdir(vim.fn.getcwd().."/build")
                    end
                    utils.runInTerminal([[cmake -G "MinGW Makefiles" -B build -S . -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DCMAKE_EXPORT_COMPILE_COMMANDS=1 --install-prefix "C:\Users\sfman\Packages\Installed" && cmake --build build && cmake --install build --config Debug]])
                else
                    print(package_folder.." is not a valid directory")
                end
            end,
        },
    }
})

--[[
vim.api.nvim_create_user_command(
    "Test",
    function (_)
        oneup.new_options_preview_menu(
            --actions
            {
                {
                    desc = "action 1",
                    callback = function() print("action 1") end,
                    preview = { "action 1 l1", "action 1 l2", "action 1 l3" }
                },
                {
                    desc = "action 2",
                    callback = function() print("action 2") end,
                    preview = function() return { "action 2 l1", "action 2 l2" } end
                },
                {
                    desc = "action 3",
                    callback = function() print("action 3") end,
                    preview = { "action 3 l1" }
                },
            },
            --opts
            {
                height = 30,
                menu_width = 20,
                preview_width = 50,
                menu_title = "menu",
                preview_title = "preview",
            },
            true
        )
    end,
    {
        nargs = 0,
        desc = "sets colors to light theme",
    }
)
]]


return M
