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
    if not utils.isDirectory(path) then
        vim.uv.fs_mkdir(path, tonumber("777", 8))
    end
end

local actionsData = {}

---@class ActionDescriptor
---@field bind string the keybinding for the action
---@field desc string the displayed discription of the action
---@field callback fun(data: table?) the function to call when the action is used
---@field type string? the type of data that needs to be loaded for the action
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

---saves the data for the given action type
---@param type string
local function saveActionsData(type)
    if actionsData[type] == nil then return end

    ---@type string
    local dataPath = vim.fn.stdpath("data") .. "/director"

    ---@type string
    local manifestPath = dataPath .. "/manifest.json"

    ---@type string
    local folderName = vim.fn.json_decode(vim.fn.readfile(manifestPath))[vim.fn.getcwd()]

    ---@type string
    local typePath = dataPath .. "/" .. folderName .. "/" .. type .. ".json"

    ---@type file*?
    local typeFile = io.open(typePath, "w")
    if typeFile ~= nil then
        typeFile:write(vim.fn.json_encode(actionsData[type]))
        typeFile:close()
    else
        print("unable to write to file: " .. typePath)
    end
end

---loads action data for the given directory and types into memory (actionsData variable),
---writing files to disk if necessary
---@param types string[] a list of all action data types that must be loaded
local function loadActionsData(types)
    --exit early if there is no data to load
    if #types <= 0 then return end

    actionsData = {}

    if not config.preserve then
        for _, type in pairs(types) do
            actionsData[type] = {
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
    for _, type in pairs(types) do
        local typePath = actionsPath .. "/" .. type .. ".json"

        --check if data is readable
        if vim.fn.filereadable(typePath) then
            --read the file into memory
            actionsData[type] = vim.fn.json_decode(vim.fn.readfile(typePath))

        else
            --if data is not readable, create a new file
            local typeFile = io.open(typePath, "w")
            if typeFile ~= nil then
                typeFile:write(vim.fn.json_encode({
                    actions = {}
                }))
                typeFile:close()
            else
                print("unable to write to file: " .. typePath)
            end

            actionsData[type] = { actions = {} }
        end
    end
end

---adds or edits an action configuration for the given type
---@param type string the type of action to add a config for
---@param label string the label for the action
---@param data table the configuration to store
function M.makeActionConfig(type, label, data)
    if actionsData[type] == nil then
        error("Action type '" .. type .. "' does not exist for this directory.")
    end

    actionsData[type].actions[label] = data

    if config.preserve then
        saveActionsData(type)
    end
end

---removes an action configuration for the given type
---@param type string the type of action to remove
---@param label string the label of the action to remove
function M.removeActionConfig(type, label)
    if actionsData[type] == nil then
        error("Action type '" .. type .. "' does not exist for this directory.")
    end

    actionsData[type].actions[label] = nil

    if config.preserve then
        saveActionsData(type)
    end
end

---sets the current action for the given type
---@param type string the type of action to set
---@param label string the label of the action to set
function M.setActionConfig(type, label)
    if actionsData[type] == nil then
        error("Action type '" .. type .. "' does not exist for this directory.")
    end

    if actionsData[type][label] == nil then
        error("Action '" .. label .. "' in '" .. type .. "' does not exist for this directory.")
    end

    actionsData[type].current = label

    if config.preserve then
        saveActionsData(type)
    end
end

function M.refreshActions()
    --detect and load actions
    ---@type { [string]: ActionDescriptor }
    M.actions = {}
    for _, action in pairs(config.actions) do
        --check if the action should exist for the current directory
        if action.detect() then
            local actionPriority = action.priority or 0

            local existingPriority = -1
            if M.actions[action.bind] ~= nil then
                existingPriority = M.actions[action.bind].priority or 0
            end

            --only add the action with the highest priority for the same bind
            if existingPriority < actionPriority then
                M.actions[action.bind] = action
            end
        end
    end

    --load all relevant action config data
    ---@type string[]
    local requiredTypes = {}
    local typeSet = {}
    for _, action in pairs(M.actions) do
        if action.type ~= nil then
            typeSet[action.type] = true
        end
    end
    for type, _ in pairs(typeSet) do
        table.insert(M.requiredTypes, type)
    end
    loadActionsData(requiredTypes)
end

function M.actionsMenu()
    if #M.actions == 0 then
        print("No Actions are Valid for this Directory")
        return
    end

    local tasks = {}
    for _, action in pairs(M.actions) do
        ---@type function
        local cb

        if action.type == nil then
            cb = action.callback
        else
            local thisData = actionsData[vim.fn.getcwd()][action]
            cb = function()
                action.callback(actionsData[action.type].actions[actionsData[action.type].current])
            end
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
            closeBinds = { "<C-c>" }
        }
    )
end

M.setup({})

vim.api.nvim_create_user_command(
    "Test",
    function(_)
        M.actionsMenu()
    end,
    {
        nargs = 0,
        desc = "Refreshes the current buildsystem",
    }
)

return M
