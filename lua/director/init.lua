local M = {}

local OptionsPopup = require("oneup.options_popup")
local utils = require("director.utils")

---@alias ConfigFieldType
---| '"boolean"'
---| '"number"'
---| '"string"'
---| '"boolean list"'
---| '"number list"'
---| '"string list"'

---@class ConfigField
---@field name string           the name/key for the field
---@field type ConfigFieldType  the datatype of the configuration fieldd
---@field default any           the default value (or function provider) of the field. type should match self.type

---@class ConfigDescriptor
---@field fields ConfigField[]              a list of possible fields for an action
---@field validate (fun(table): boolean)?   a function used to validate a configuration

---@class DirectorBindsConfig
---@field up string[]       a list of binds used to move cursor upwards in the menus
---@field down string[]     a list of binds used to move cursor downwards in the menus
---@field confirm string[]  a list of binds used to confirm a selection
---@field edit string[]     a list of binds used to begin editing a config or field
---@field new string[]      a list of binds used to create a new config preset
---@field cancel string[]   a list of binds used to return to the previous menu (or close the menu)

---@alias ConfigName string the name of a configuration defined by keys in main_config.config_types
---@alias ConfigKey string  a key corresponding to a given ConfigField defined in main_config.config_types[i]
---@alias ActionConfig { [ConfigName]: { [ConfigKey]: any } }

---@class ActionDescriptor
---@field desc string               the displayed discription of the action
---@field callback fun(config: ActionConfig) | fun()   the function to call when the action is run
---@field bind string?              the keybinding for the action
---@field configs string[]?         a list of config types required by the action
---@field priority number?          if keybinds conflict, the action with the higher priority is bound (default 0 for cwd actions, 100 for file actions)

---@class ActionGroup
---@field file_local boolean?           Whether the action group applies to a certain file type (alternatively applying to the working directory)
---@field detect fun(): boolean         A function that determines if the actions in the group should be loaded
---@field actions ActionDescriptor[]    A list of actions belonging to the group
---@field config_types table<string, ConfigDescriptor>? a map defining names for config types, allowing them to be reused but work as configs for separate actions
---@field priority number?              If keybinds conflict, the default priority of all actions in the group (default 0 for cwd actions, 100 for file actions)

---@class DirectorConfig
---@field preserve boolean                      whether or not to save in-editor configuration to disk
---@field binds DirectorBindsConfig             binds for menus
---@field actions table<groupName, ActionGroup> a list of action groups that may be used
---@field cwd_actions table<groupName, ActionGroup> a list of action groups that may be used in the cwd
---@field file_actions table<groupName, ActionGroup> a list of action groups that may be used in the file

---@alias bind string
---@alias path string
---@alias groupName string

---@alias ActionDataContainer { bound: table<bind, ActionDescriptor>, unbound: ActionDescriptor[] }

---@alias ConfigData { active: string?, presets: { [string]: table } } data for a configuration, including the active configuration and presets

---@type DirectorConfig
local main_config = {} ---@diagnostic disable-line:missing-fields

--action configuration
--config_data[path][group][config_name] -> {current(current action key), actions(name -> data) }
---@type { [path]: { [groupName]: { [ConfigName]: ConfigData } } }
local config_data = {}

-- list of directory actions
---@type { [groupName]: { bound: table<bind, ActionDescriptor>, unbound: ActionDescriptor[] } }
local cwd_actions = {}

---@alias CwdBindInfo { priority: integer, group_name: groupName }
-- a map bind -> bind info
---@type table<bind, CwdBindInfo>
local cwd_bind_info = {}

-- list of file actions
---@type { [path]: { [groupName]: { bound: table<bind, ActionDescriptor>, unbound: ActionDescriptor[] } } }
local file_actions = {}

---@alias FileBindInfo { priority: integer, path: path, group_name: groupName }
-- a map bind -> bind info
---@type { [path]: table<bind, FileBindInfo> }
local file_bind_info = {}

---setup the plugin
---@param opts? table
function M.setup(opts)
    local default = require("director.defaults")

    ---@type DirectorConfig
    main_config = opts or {}
    if main_config.actions == nil then main_config.actions = default.actions end
    if main_config.preserve == nil then main_config.preserve = default.preserve end
    if main_config.binds == nil then main_config.binds = {} end ---@diagnostic disable-line:missing-fields
    main_config.binds = vim.tbl_extend("force", main_config.binds, default.binds)

    main_config.file_actions = {}
    main_config.cwd_actions = {}
    for group_name, group in pairs(main_config.actions) do
        if group.file_local then
            main_config.file_actions[group_name] = group
        else
            main_config.cwd_actions[group_name] = group
        end
    end

    vim.api.nvim_create_autocmd(
        'DirChanged',
        {
            pattern = 'global',
            callback = function()
                M.refreshCwdActions()
                file_actions = {}
                file_bind_info = {}
            end
        }
    )

    vim.api.nvim_create_autocmd(
        'UIEnter',
        {
            callback = function()
                M.refreshCwdActions()
                file_actions = {}
                file_bind_info = {}
            end
        }
    )

    vim.api.nvim_create_autocmd(
        'BufEnter',
        {
            callback = M.loadFileActions
        }
    )

    vim.api.nvim_create_user_command(
        "Director",
        function (cmd)
            local help = function()
                print("Director command can be run with the following arguments:")
                print("\t     (m)ain - to list all loaded commands")
                print("\t(d)irectory - to list all working directory commands")
                print("\t     (f)ile - to list all file commands")
                print("\t    (q)uick - to list all commands with keybinds")
                print("\t   (c)onfig - to open the configuration menu")
            end

            if cmd.fargs[1] == nil then
                help()
                return
            end

            local arg = string.lower(string.sub(cmd.fargs[1], 1, 1))
            if arg == "m" then
                M.mainMenu()
            elseif arg == "d" then
                M.directoryMenu()
            elseif arg == "f" then
                M.fileMenu()
            elseif arg == "q" then
                M.quickMenu()
            elseif arg == "c" then
                M.configMenu()
            else
                help()
            end
        end,
        {
            nargs = "?",
            desc = "Opens the specified Director popup menu",
        }
    )
end

---reads the manifest file, returning the data folder corresponding to the given path
---@param path string the path to be searched for
---@return string configPath the path at which to find data for the given path
local function queryManifest(path)
    --read/write to manifest file
    ---@type string
    local data_path = vim.fn.stdpath("data") .. "/director"

    ---@type string
    local manifest_path = data_path .. "/manifest.json"

    ---@type string
    local folder_name

    --check if manifest file exists
    local manifest = utils.safeJsonDecode(manifest_path)
    if manifest ~= nil then
        --if directory is not in the manifest, add it to the manifest
        if manifest[path] == nil then
            --determine a suitable name for the data folder
            local folder = 0
            while true do
                if not vim.fn.isdirectory(data_path .. tostring(folder)) then
                    folder_name = tostring(folder)
                    manifest[path] = folder_name
                    break
                end
                folder = folder + 1
            end

            --write the updated data to the manifest file
            local manifest_file = io.open(manifest_path, "w")
            if manifest_file ~= nil then
                manifest_file:write(vim.fn.json_encode(manifest))
                manifest_file:close()
            else
                error("unable to write to file: " .. manifest_path)
            end
        else
            --if the directory is in the manifest, we know the folder name
            folder_name = manifest[path]
        end

    else

        --if manifest file does not exist, create a new one
        M.mkdir(data_path)
        local manifest_file = io.open(manifest_path, "w")
        if manifest_file ~= nil then
            manifest_file:write(vim.fn.json_encode({
                [path] = "0"
            }))
            manifest_file:close()
        else
            error("unable to write to file: " .. manifest_path)
        end

        folder_name = "0"
    end

    return folder_name
end

---determines if a configuration preset matches is descriptor
---@param preset table<string, any> the configuration
---@param config_desciptor ConfigDescriptor the specification for the config
---@return table<string, any>? trimmed_config the configuration, trimmed of any extra/unspecified keys, or nil if the configuration is invalid
local function isPresetValid(preset, config_desciptor)
    local out = {}

    --ensure fields match those in the config descriptor
    for _, field in pairs(config_desciptor.fields) do
        if preset[field.name] == nil then return nil end

        local field_value = preset[field.name]
        if field.type:sub(-4) ~= "list" then
            if field.type ~= type(field_value) then return nil end

        elseif field.type:sub(-4) == "list" then
            if type(field_value) ~= "table" then return nil end
            local main_type = field.type:sub(1, -6)

            for _, item in pairs(field_value) do
                if type(item) ~= main_type then return nil end
            end
        else
            print("Invalid field type '" .. field.type .. "' in ConfigDescriptor.")
            return
        end

        out[field] = field_value
    end

    --ensure config passes optional validation
    if config_desciptor.validate == nil or config_desciptor.validate(out) then
        return out
    else
        return nil
    end
end

---saves to disk the data for the given group configuration
---must ensure that all parameters are correct before calling the function
---@param path path the path of the scope for the config
---@param group_name groupName the name of the group
---@param config_name string the name of the group configuration to save
local function saveGroupConfig(path, group_name, config_name)
    local group_data_folder = queryManifest(path) .. "/" .. group_name
    utils.mkdir(group_data_folder)

    local config_path = group_data_folder .. "/" .. config_name .. ".json"

    ---@type file*?
    local config_file = io.open(config_path, "w")
    if config_file ~= nil then
        config_file:write(vim.fn.json_encode(config_data[path][group_name][config_name]))
        config_file:close()
    else
        error("Unable to save group config. Cannot write to file '" .. config_file .. "'.")
    end
end

---loads from disk the config data for the given group
---@param path path the name of the scope for the config
---@param group_name groupName the group for which to load configs
local function loadGroupConfigs(path, group_name)
    local group = main_config.actions[group_name]
    --skip the stress if theres nothing to load
    if group.config_types == nil or #group.config_types <= 0 then
        return
    end

    --find and ensure existence of data folder for group
    ---@type string
    local data_folder = queryManifest(path)

    ---@type string
    local group_data_folder = data_folder .. "/" .. group_name
    utils.mkdir(group_data_folder)

    --load group configs
    for name, _ in pairs(group.config_types) do
        if not utils.isValidName(name) then
            print(
                "Attempted to load config with invalid name '" .. group_name .. "'."
                .. "Names may only contain alphanumeric characters, underscores, and spaces."
            )
        else

            --read config file
            local config_path = group_data_folder .. "/" .. name .. ".json"

            ---@type ConfigData
            local config = utils.safeJsonDecode(config_path)

            --load config presets
            config_data[path][group_name][name] = { active = nil, presets = {} }
            if config ~= nil and config.presets ~= nil then
                for preset_name, preset in pairs(config.presets) do
                    if not utils.isValidName(preset_name) then
                        print(
                            "Attempted to load preset with invalid name '" .. preset_name .. "'."
                            .. "Names may only contain alphanumeric characters, underscores, and spaces."
                        )
                    else
                        local updated_preset = isPresetValid(preset, group.config_types[name])
                        if updated_preset ~= nil then
                            config_data[path][group_name][name].presets[preset_name] = updated_preset
                        end
                    end
                end
            end

            --ensure active preset is still valid and load it if so
            if
                config ~= nil
                and type(config.active) == "string"
                and config_data[path][group_name][name].presets[config.active] ~= nil
            then
                config_data[path][group_name][name].active = config.active
            end

            --save data which may have been updated/validated upon loading
            saveGroupConfig(path, group_name, name)

        end
    end
end

---loads actions for the given group
---@param group_name groupName the group for which to load configs
---@param load_location ActionDataContainer the place in which to load the actions
---@param bind_info_location table<bind, CwdBindInfo> | table<bind, FileBindInfo>
---@param path? path optional path field to add to bind_info_location
local function loadGroupActions(group_name, load_location, bind_info_location, path)
    local group = main_config.actions[group_name]
    for _, action in pairs(group.actions) do
        if action.bind == nil then
            table.insert(load_location.unbound, action)
        else
            --handle unused bind
            if bind_info_location[action.bind] == nil then
                load_location.bound[action.bind] = action
                bind_info_location[action.bind] = {
                    priority = action.priority,
                    group_name = group_name,
                    path = path
                }

            --handle reused bind
            else
                local existing_priority = bind_info_location[action.bind].priority
                if existing_priority == nil then existing_priority = 0 end

                local this = action.priority
                if this == nil then this = 0 end

                --overwrite old bind
                if this > existing_priority then
                    table.insert(load_location.unbound, load_location.bound[action.bind])
                    load_location.bound[action.bind] = action
                    bind_info_location[action.bind] = {
                        priority = action.priority,
                        group_name = group_name,
                        path = path
                    }

                    --load action without binding
                else
                    table.insert(load_location.unbound, action)
                end
            end
        end
    end
end

---refreshes actions belonging to the current working directory
function M.refreshCwdActions()
    local cwd = vim.fn.getcwd() .. "/"

    cwd_actions = {}
    cwd_bind_info = {}

    --load groups
    for name, group in pairs(main_config.cwd_actions) do
        local no_skip = true
        if group.file_local or not group.detect() then no_skip = false end

        if not utils.isValidName(name) then
            print(
                "Attempted to load group with invalid name '" .. name .. "'."
                .. "Names may only contain alphanumeric characters, underscores, and spaces."
            )
            no_skip = false
        end

        if no_skip then
            cwd_actions[name] = { bound = {}, unbound = {} }

            loadGroupConfigs(cwd, name)
            loadGroupActions(name, cwd_actions[name], cwd_bind_info, nil)
        end
    end
end

---refreshes actions belonging to the current working directory
function M.loadFileActions()
    local path = vim.fn.expand("%:p")

    if vim.fn.filereadable(path) ~= 1 then return end
    if file_actions[path] ~= nil then return end

    file_actions[path] = {}
    file_bind_info[path] = {}

    --load groups
    for name, group in pairs(main_config.file_actions) do
        local no_skip = true
        if (not group.file_local) or (not group.detect()) then no_skip = false end

        if not utils.isValidName(name) then
            print(
                "Attempted to load group with invalid name '" .. name .. "'."
                .. "Names may only contain alphanumeric characters, underscores, and spaces."
            )
            no_skip = false
        end

        if no_skip then
            file_actions[path][name] = { bound = {}, unbound = {} }

            loadGroupConfigs(path, name)
            loadGroupActions(name, file_actions[path][name], file_bind_info[path], path)
        end
    end
end

---returns the table that will be passed to the given action's callback when ran
---@param path path the path scope of the action
---@param group_name groupName the name of the group in which the action is found
---@param action_configs ConfigName[] a list of configs to load from the given group
---@return ActionConfig config the configuration to be passed to the action
function M.getActionConfigs(path, group_name, action_configs)
    ---@type ActionConfig
    local out = {}

    ---@type table<ConfigName, ConfigData>
    local action_data = config_data[path][group_name]

    for _, config_name in pairs(action_configs) do
        table.insert(
            out,
            action_data[config_name].presets[action_data[config_name].active]
        )
    end

    return out
end

---opens an actions menu with the given actions under each group name specified
---@param title string the title to display for the menu
---@param actions { [groupName]: ActionDataContainer }
---@param file_path string the file on which to call file-local actions
function openActionsMenu(title, actions, file_path)
    ---@type Option[]
    local options = {}
    local longest_bind = 0

    --determine longest bind length
    for _, action_data in pairs(actions) do
        for bind, _ in pairs(action_data.bound) do
            longest_bind = math.max(#bind, longest_bind)
        end
    end

    local hyphen = ""
    if longest_bind > 0 then hyphen = " - " end

    ---@type table<bind, function>
    local bind_map = {}

    --insert options
    local groups = 0
    for group_name, action_data in pairs(actions) do
        --insert group separator
        table.insert(options, { text = group_name, is_title = true })
        groups = groups + 1

        --determine path for any configurable callbacks
        ---@type string
        local path
        if main_config.actions[group_name].file_local then
            path = file_path
        else
            path = vim.fn.getcwd().."/"
        end

        --generate bound options
        for _, action in pairs(action_data.bound) do
            --determine keymap callback
            ---@type function
            local callback
            if action.configs == nil then
                callback = action.callback
            else
                callback = function()
                    action.callback(M.getActionConfigs(path, group_name, action.configs))
                end
            end

            bind_map[action.bind] = callback

            table.insert(options, {
                text = string.rep(" ", longest_bind - #action.bind) .. action.bind .. hyphen .. action.desc,
                callback = callback
            })
        end

        --generate unbound options
        for _, action in pairs(action_data.unbound) do
            --determine keymap callback
            ---@type function
            local callback
            if action.configs ~= nil then
                callback = action.callback
            else
                callback = function()
                    action.callback(M.getActionConfigs(path, group_name, action.configs))
                end
            end

            table.insert(options, {
                text = string.rep(" ", longest_bind) .. hyphen .. action.desc,
                callback = callback
            })
        end
    end

    if #options <= groups then
        print("Failed to open menu. No actions detected.")
        return
    end

    local p = OptionsPopup:new({
        title = title,
        border = true,
        width = "40%",
        min_width = 25,
        height = "80%",

        options = options
    }, true)

    --set keybinds
    for _, up_bind in pairs(main_config.binds.up) do
        p:set_keymap("n", up_bind, function() p:prev_option() end)
    end
    for _, down_bind in pairs(main_config.binds.down) do
        p:set_keymap("n", down_bind, function() p:next_option() end)
    end
    for _, cancel_bind in pairs(main_config.binds.cancel) do
        p:set_keymap("n", cancel_bind, function() p:close() end)
    end
    for _, confirm_bind in pairs(main_config.binds.confirm) do
        p:set_keymap("n", confirm_bind, function()
            p:get_option().callback()
            p:close()
        end)
    end
    for bind, callback in pairs(bind_map) do
        p:set_keymap("n", bind, function()
            callback()
            p:close()
        end)
    end
end

---accesses all detected actions with bindings into a menu
function M.quickMenu()
    ---@type { [groupName]: ActionDataContainer }
    local actions = {}

    for bind, bind_info in pairs(cwd_bind_info) do
        if actions[bind_info.group_name] == nil then
            actions[bind_info.group_name] = { bound = {}, unbound = {} }
        end

        actions[bind_info.group_name].bound[bind] = cwd_actions[bind_info.group_name].bound[bind]
    end

    local file_path = vim.fn.expand("%:p")
    if vim.fn.filereadable(file_path) == 1 then
        for bind, bind_info in pairs(file_bind_info[file_path]) do
            if actions[bind_info.group_name] == nil then
                actions[bind_info.group_name] = { bound = {}, unbound = {} }
            end

            local file_action = file_actions[file_path][bind_info.group_name].bound[bind]

            --handle priority
            if cwd_bind_info[bind] == nil then
                actions[bind_info.group_name].bound[bind] = file_action
            else
                local priority = 100
                if file_action.priority ~= nil then
                    priority = file_action.priority
                end

                local cwd_priority = 0
                if cwd_bind_info[bind].priority ~= nil then
                    cwd_priority = cwd_bind_info[bind].priority
                end

                if priority >= cwd_priority then
                    actions[bind_info.group_name].bound[bind] = file_action
                    actions[cwd_bind_info[bind].group_name].bound[bind] = nil
                end
            end
        end
    end

    openActionsMenu(" Quick Actions ", actions, file_path)
end

---accesses all detected actions for the cwd
function M.directoryMenu()
    local file_path = vim.fn.expand("%:p")

    openActionsMenu(" Directory Actions ", cwd_actions, file_path)
end

---accesses all detected active file-specific actions
function M.fileMenu()
    local file_path = vim.fn.expand("%:p")

    if vim.fn.filereadable(file_path) == 1 then
        openActionsMenu(" File Actions ", file_actions[file_path], file_path)
    else
        print("Director File Menu could not be opened for the current buffer as it is not associated to a file.")
    end
end

---accesses all detected actions
function M.mainMenu()
    ---@type { [groupName]: ActionDataContainer }
    local actions = {}

    for name, group in pairs(cwd_actions) do
        actions[name] = { bound = {}, unbound = {} }

        for bind, action in pairs(group.bound) do
            actions[name].bound[bind] = action
        end

        for idx, action in pairs(group.unbound) do
            actions[name].unbound[idx] = action
        end
    end

    local file_path = vim.fn.expand("%:p")
    if vim.fn.filereadable(file_path) == 1 then
        for name, group in pairs(file_actions[file_path]) do
            actions[name] = { bound = {}, unbound = {} }

            for bind, action in pairs(group.bound) do

                local priority = 100
                if action.priority ~= nil then
                    priority = action.priority
                end

                local cwd_priority = 0
                local cwd_group = cwd_bind_info[bind].group_name
                if cwd_bind_info[bind].priority ~= nil then
                    cwd_priority = cwd_bind_info[bind].priority
                end

                if priority >= cwd_priority then
                    actions[name].bound[bind] = action
                    table.insert(actions[cwd_group].unbound, actions[cwd_group].bound[bind])
                    actions[cwd_group].bound[bind] = nil
                else
                    table.insert(actions[name].unbound, action)
                end
            end

            for idx, action in pairs(group.unbound) do
                actions[name].unbound[idx] = action
            end
        end
    end

    openActionsMenu(" All Actions ", actions, file_path)
end

---accesses mainMenu action configurations
function M.configMenu()
    error("todo")
end

M.setup()

vim.keymap.set(
    "n",
    "<leader>b",
    M.quickMenu
)

return M
