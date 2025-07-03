local M = {}

local OptionsPopup = require("oneup.options_popup")
local utils = require("director.utils")

---@type DirectorConfig
local default = require("director.defaults")

---@type DirectorConfig
local main_config

--action configuration
---@type { [path]: { [ConfigName]: { current: string, actions: { [string]: table } } } }
local actionsData = {}

-- list of file actions
---@type { [path]: { bound: { [bind]: ActionDescriptor }, unbound: ActionDescriptor[] } }
local file_actions = {}

-- list of directory actions
---@type { bound: table<bind, ActionDescriptor>, unbound: ActionDescriptor[] }
local cwd_actions = {}

-- list of directory actions

---setup the plugin
---@param opts table
function M.setup(opts)
    ---@type DirectorConfig
    main_config = vim.tbl_deep_extend('force', default, opts or {})

    vim.api.nvim_create_autocmd(
        'DirChanged',
        {
            pattern = 'global',
            callback = M.refreshCwdActions,
        }
    )

    vim.api.nvim_create_autocmd(
        'VimEnter',
        {
            callback =  M.refreshCwdActions,
        }
    )
end

---saves the data for the given action bind and the given path
---@param bind string
---@param path string
local function saveActionsData(path, bind)
    if actionsData[path] == nil then return end
    if actionsData[path][bind] == nil then return end

    ---@type string
    local dataPath = vim.fn.stdpath("data") .. "/director"

    ---@type string
    local manifestPath = dataPath .. "/manifest.json"

    ---@type string
    local folderName = vim.fn.json_decode(vim.fn.readfile(manifestPath))[path]

    ---@type string
    local bindPath = dataPath .. "/" .. folderName .. "/" .. bind .. ".json"

    ---@type file*?
    local bindFile = io.open(bindPath, "w")
    if bindFile ~= nil then
        bindFile:write(vim.fn.json_encode(actionsData[path][bind]))
        bindFile:close()
    else
        print("unable to write to file: " .. bindPath)
    end
end

---loads action data for the given directory and binds into memory (actionsData variable),
---writing files to disk if necessary
---@param binds string[] a list of all binds for which ations must be loaded
local function loadActionsData(binds)
    --exit early if there is no data to load
    do
        local _, v = next(binds)
        if v == nil then return end
    end

    actionsData = {}

    if not main_config.preserve then
        for _, config_type in pairs(binds) do
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
        M.mkdir(dataPath)
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
    utils.mkdir(actionsPath)

    --for action data of each type...
    for _, bind in pairs(binds) do
        local typePath = actionsPath .. "/" .. bind .. ".json"

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

            actionsData[bind] = { actions = {} }
        end
    end
end

---adds or edits an action configuration for the given bind
---@param path string the execution path for the action
---@param bind string the bind of action to add a config for
---@param label string the label for the action
---@param data table the configuration to store
function M.makeActionConfig(path, bind, label, data)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    actionsData[bind].actions[label] = data

    if main_config.preserve then
        saveActionsData(path, bind)
    end
end

---removes an action configuration for the given bind
---@param path string the execution path for the action
---@param bind string the bind at which to remove a configuration
---@param label string the label of the action config to remove
function M.removeActionConfig(path, bind, label)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    actionsData[bind].actions[label] = nil

    if main_config.preserve then
        saveActionsData(path, bind)
    end
end

---sets the current action config for the given bind 
---@param path string the execution path for the action
---@param bind string the bind of action to set
---@param label string the label of the action to set
function M.setActionConfig(path, bind, label)
    if actionsData[bind] == nil then
        error("Action bind '" .. bind .. "' is not configurable for this directory.")
    end

    if actionsData[path][bind].actions[label] == nil then
        error("Action bind '" .. bind .. "' does not have a config '" .. label "'")
    end

    actionsData[path][bind].current = label

    if main_config.preserve then
        saveActionsData(path, bind)
    end
end

---refreshes actions for the current working directory, clears memory of file actions
function M.refreshCwdActions()
    --detect and load actions
    actions = {}
    local cwd = vim.fn.getcwd()
    for _, action in pairs(main_config.cwd_actions) do
        --check if the action should exist for the current directory
        if action.detect() then
            local actionPriority = action.priority or 0

            local existingPriority = -1
            if actions[action.bind] ~= nil then
                existingPriority = actions[action.bind].data.priority or 0
            end

            --only add the action with the highest priority for the same bind
            if existingPriority < actionPriority then
                actions[action.bind] = { scope = cwd, data = action }
            end
        end
    end

    --load all relevant action config data
    ---@type string[]
    local configure_types = {}
    for _, action in pairs(actions) do
        if action.data.configure_type ~= nil then
            table.insert(configure_types, action.data.configure_type)
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
        if action.data.bind == nil then break end
        maxBindLength = math.max(maxBindLength, #action.data.bind)
    end

    if maxBindLength > 0 then hyphen = " - " end

    ---@type { callback: function, bind: string }[]
    local bindedActions = {}
    ---@type Option[]
    local actionOptions = {}
    for _, action in pairs(actions) do
        ---@type function
        local callback

        if action.data.configure_type ~= nil then
            callback = function()
                action.data.callback(actionsData[action.data.bind].actions[actionsData[action.data.bind].current])
            end
        else
            callback = action.data.callback
        end

        local text
        if action.data.bind == nil then
            text = string.rep(" ", maxBindLength) .. hyphen .. action.data.desc
        else
            text = string.rep(" ", maxBindLength - #action.data.bind) .. action.data.bind .. hyphen .. action.data.desc

            table.insert(bindedActions, {
                bind = action.data.bind,
                callback = callback,
                action.data.configure_type
            })
        end

        table.insert(actionOptions, {
            text = text,
            callback = callback
        })
    end

    local menu = OptionsPopup:new(
        {
            title = "Actions",
            min_width = 20,
            border = true,
            closeBinds = main_config.binds.cancel,
            selectBinds = main_config.binds.confirm,
            options = actionOptions
        },
        true
    )

    for _, bind in pairs(main_config.binds.confirm) do
        menu:set_keymap("n", bind, function()
            menu:get_option().callback()
        end)
    end

    for _, bind in pairs(main_config.binds.cancel) do
        menu:set_keymap("n", bind, function() menu:close() end)
    end

    for _, bind in pairs(main_config.binds.edit) do
        menu:set_keymap("n", bind, function()
            local opt = menu:get_option()
            if opt ~= nil then M.actionConfigMenu(opt.bind) end
        end)
    end

    for _, binded in pairs(bindedActions) do
        menu:set_keymap("n", binded.bind, binded.callback)
    end

end

--[[
---opens the action configuration menu for the given bind
---@param bind string the bind type to open the action menu for
function M.actionConfigMenu(bind)
    if actions[bind] == nil or actions[bind].data.configure_type == nil then
        print("Action with bind '" .. bind .. "' is not configurable.")
        return
    end

    --define config previews
    local configs = {}

    for name, action in pairs(actionsData[bind].actions) do
        ---@type PreviewedOption
        local preview = {}

        for _, f in main_config.action_types[actions[bind].data.configure_type] do
            ---@type ActionConfigField
            local field = f

            table.insert(preview, field.name .. ":")

            if field.is_list then
                for _, element in action[field.name] do
                    table.insert(preview, "\t" .. element )
                end
            else
                table.insert(preview, "\t" .. action[field.name])
            end
        end
    end
end
]]

M.setup({
    ---@type ActionGroup[]
    cwd_actions = {
        require("director.actions.cargo"),
        require("director.actions.cmake"),
    }
})

return M
