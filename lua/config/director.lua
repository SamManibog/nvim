local M = {}

local popup = require("config.popup")
local utils = require("config.utils")

---@diagnostic disable: unused-function, unused-local

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

-- action configuration
local actionsData = {}

-- list of actions
local actions = {}

---@class ActionDescriptor
---@field bind string the keybinding for the action
---@field desc string the displayed discription of the action
---@field callback fun(data: table?) the function to call when the action is used
---@field configurable boolean? whether or not a configuration table can be passed to the callback
---@field detect (fun(): boolean)? the function ran to detect if the action is available (always available if nil)
---@field priority number? if keybinds conflict, the action with the higher priority is used (default 0)

---@class DirectorConfig
---@field preserve boolean whether or not to save in-editor configuration to disk
---@field actions ActionDescriptor[] a list of action descriptors that may be used

---@type DirectorConfig
local default = {
    preserve = true,
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
---@param binds string[] a list of all binds with data that must be loaded
local function loadActionsData(binds)
    --exit early if there is no data to load
    do
        local _, v = next(binds)
        if v == nil then return end
    end

    actionsData = {}

    if not config.preserve then
        for _, bind in pairs(binds) do
            actionsData[bind] = {
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

    --for action data of each bind...
    for _, bind in pairs(binds) do
        local bindPath = actionsPath .. "/" .. bind .. ".json"

        --check if data is readable
        if vim.fn.filereadable(bindPath) then
            --read the file into memory
            actionsData[bind] = vim.fn.json_decode(vim.fn.readfile(bindPath))

        else
            --if data is not readable, create a new file
            local bindFile = io.open(bindPath, "w")
            if bindFile ~= nil then
                bindFile:write(vim.fn.json_encode({
                    actions = {}
                }))
                bindFile:close()
            else
                print("unable to write to file: " .. bindPath)
            end

            actionsData[bind] = { actions = {} }
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
    local configurables = {}
    for _, action in pairs(actions) do
        if action.configurable then
            table.insert(configurables, action)
        end
    end
    loadActionsData(configurables)
end

function M.actionsMenu()
    do
        local _, v = next(actions)
        if v == nil then
            print("No actions are valid for this directory.")
            return
        end
    end

    local tasks = {}
    for _, action in pairs(actions) do
        ---@type function
        local cb

        if action.configurable then
            local thisData = actionsData[vim.fn.getcwd()][action]
            cb = function()
                action.callback(actionsData[action.bind].actions[actionsData[action.bind].current])
            end
        else
            cb = action.callback
        end

        table.insert(tasks, {
            bind = action.bind,
            desc = action.desc,
            callback = cb
        })
    end

    popup.new_actions_menu(
        tasks,
        {
            title = "Actions",
            width = 30,
            border = true,
            closeBinds = { "<C-c>" },
            selectBinds = { "<CR>", "<Space>" }
        }
    )
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

return M
