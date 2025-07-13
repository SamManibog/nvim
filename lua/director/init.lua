local M = {}

local Popup = require("oneup.popup")
local PromptPopup = require("oneup.prompt_popup")
local OptionsPopup = require("oneup.options_popup")
local PreviewPopup = require("oneup.previewed_options_popup")
local Line = require("oneup.line")
local Text = require("oneup.text")
local utils = require("director.utils")

---@alias ConfigFieldType
---| '"string"'     a string value
---| '"number"'     a number value
---| '"boolean"'    a boolean value
---| '"option"'     one (string) option from a provided list of options
---| '"list"'       a list of strings

---@class ConfigField
---@field name string           the name/key for the field
---@field type ConfigFieldType  the datatype of the configuration fieldd
---@field default any           the default value (or function provider) for the field. type should match self.type. if type is option, default instead provides the options used where the first option provided is the true default value
---@field validate (fun(any): boolean)?   a function used to validate the field

---@class DirectorBindsConfig
---@field up string[]           a list of binds used to move cursor upwards in the menus
---@field down string[]         a list of binds used to move cursor downwards in the menus
---@field select string[]       a list of binds used to confirm a selection or edit a profile
---@field new string[]          a list of binds used to create a new config profile
---@field rename string[]       a list of binds used to rename profiles
---@field delete string[]       a list of binds used to delete profiles
---@field edit string[]         a list of binds used to edit a config profile
---@field cancel string[]       a list of binds used to return to the previous menu (or close the menu)
---@field quick_menu string[]   a list of binds used to list all actions with keybinds
---@field file_menu string[]    a list of binds used to list all actions pertaining to the current file buffer
---@field directory_menu string[]   a list of binds used to list all actions pertaining to the current working directory
---@field main_menu string[]    a list of binds used to list all loaded actions
---@field config_menu string[]  a list of binds used to list all loaded configs

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
---@field config_types table<string, ConfigField[]>? a map defining names for config types, allowing them to be reused but work as configs for separate actions
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
---@alias configName string

---@alias ActionDataContainer { bound: table<bind, ActionDescriptor>, unbound: ActionDescriptor[] }

---@alias ConfigData { active: string?, profiles: { [string]: table } } data for a configuration, including the active configuration and profiles

---@type DirectorConfig global *CONSTANT* state
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

---@type { file: string?, modified: { path: path, group: groupName, config: configName }[] }
local director_state = { modified = {} }

local function flagModified(path, group, config)
    for _, mod in ipairs(director_state.modified) do
        if path == mod.path and group == mod.group and config == mod.config then
            return
        end
    end
    table.insert(director_state.modified, { path = path, group = group, config = config })
end

---@return string
local function getcwd()
    local path, _ = string.gsub(vim.fn.getcwd().."/", "\\", "/")
    return path
end

---setup the plugin
---@param opts? table
function M.setup(opts)
    local default = require("director.defaults")

    ---@type DirectorConfig
    main_config = opts or {}
    if main_config.actions == nil then main_config.actions = default.actions end
    if main_config.preserve == nil then main_config.preserve = default.preserve end
    if main_config.binds == nil then main_config.binds = {} end ---@diagnostic disable-line:missing-fields
    main_config.binds = vim.tbl_extend("keep", main_config.binds, default.binds)

    main_config.file_actions = {}
    main_config.cwd_actions = {}
    for group_name, group in pairs(main_config.actions) do
        if group.file_local then
            main_config.file_actions[group_name] = group
        else
            main_config.cwd_actions[group_name] = group
        end
    end

    --setup binds
    for key, value in pairs(main_config.binds) do
        if type(value) == "string" then
            main_config.binds[key] = { value }
        end
    end
    for _, bind in pairs(main_config.binds.main_menu) do
        vim.keymap.set("n", bind, M.mainMenu)
    end
    for _, bind in pairs(main_config.binds.quick_menu) do
        vim.keymap.set("n", bind, M.quickMenu)
    end
    for _, bind in pairs(main_config.binds.directory_menu) do
        vim.keymap.set("n", bind, M.directoryMenu)
    end
    for _, bind in pairs(main_config.binds.file_menu) do
        vim.keymap.set("n", bind, M.fileMenu)
    end
    for _, bind in pairs(main_config.binds.config_menu) do
        vim.keymap.set("n", bind, M.configMenu)
    end

    --initial refresh of cwd actions
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

    --auto refresh cwd actions
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

    --auto refresh file actions and current file
    vim.api.nvim_create_autocmd(
        'BufEnter',
        {
            callback = function()
                local path = vim.fn.expand("%:p")
                path = string.gsub(path, "\\", "/")

                if vim.fn.filereadable(path) == 1 then
                    director_state.file = path
                end

                M.loadFileActions()
            end
        }
    )

    --save data to disk before closing
    vim.api.nvim_create_autocmd(
        'ExitPre',
        {
            callback = function()
                M.saveConfigs()
            end
        }
    )

    vim.api.nvim_create_user_command(
        "DirectorSave",
        function (_)
            M.saveConfigs()
        end,
        {
            nargs = 0,
            desc = "Saves all changes made on director configurations",
        }
    )

    --Director command (to open menus) or save configs
    vim.api.nvim_create_user_command(
        "Director",
        function (cmd)
            local help ="Director command can be run with the following arguments:"
            .."\t    (q)uick - to list all commands with keybinds"
            .."\t     (m)ain - to list all loaded commands"
            .."\t(d)irectory - to list all working directory commands"
            .."\t     (f)ile - to list all file commands"
            .."\t   (c)onfig - to open the configuration menu"
            .."\t     (s)ave - to force save all configuration changes"

            if cmd.fargs[1] == nil then
                print(help)
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
            elseif arg == "s" then
                M.saveConfigs()
            else
                print(help)
            end
        end,
        {
            nargs = "?",
            desc = "Director command center"
        }
    )
end

---reads the manifest file, returning the data folder corresponding to the given path
---@param path string the path to be searched for
---@param create boolean whether to add to the existing file structure if relevant data is not found. if false, function may return nil indicating the lack of said data
---@return string? configPath the path at which to find data for the given path, if nil the manifest file has not yet been created
local function queryManifest(path, create)
    --read/write to manifest file
    ---@type string
    local director_path = vim.fn.stdpath("data") .. "/director"
    utils.mkdir(director_path)

    ---@type string
    local data_path = director_path .. "/" .. utils.getPathHash(path)
    if (not create) and vim.fn.isdirectory(data_path) ~= 1 then
        return nil
    end
    utils.mkdir(data_path)

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
        utils.mkdir(data_path)
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

    --ensure the returned folder exists
    utils.mkdir(data_path .. "/" .. folder_name)

    return data_path .. "/" .. folder_name
end

---determines if a configuration profile matches is descriptor
---@param profile table<string, any> the configuration
---@param profile_fields ConfigField[] the specification for the config
---@return table<string, any>? trimmed_config the configuration, trimmed of any extra/unspecified keys, or nil if the configuration is invalid
local function isProfileValid(profile, profile_fields)
    local out = {}

    --ensure fields match those in the config descriptor
    for _, field in pairs(profile_fields) do
        if profile[field.name] == nil then return nil end

        local field_value = profile[field.name]
        if field.type == "option" then
            if type(field_value) ~= "string" then return nil end

        elseif field.type == "list" then
            if type(field_value) ~= "table" then return nil end

            for _, item in pairs(field_value) do
                if type(item) ~= "string" then return nil end
            end
        elseif field.type == "boolean" or field.type == "string" or field.type == "number" then
            if type(field_value) ~= field.type then return nil end
        else
            print("Invalid field type '" .. field.type .. "' in profile fields.")
            return
        end

        if field.validate ~= nil then
            if not field.validate(profile[field.name]) then
                return nil
            end
        end

        out[field.name] = field_value
    end

    return out
end

---tries to clean up unececessary file structures
---@param path path the path of the scope for the config
---@param group groupName the name of the group
---@param config configName the name of the group configuration to save
local function attemptClean(path, group, config)
    local data_path = vim.fn.stdpath("data") .. "/director/" .. utils.getPathHash(path)
    local manifest_path = data_path .. "/manifest.json"

    --check if manifest file exists or is empty
    local manifest = utils.safeJsonDecode(manifest_path)
    if manifest == nil or next(manifest) == nil then
        utils.rmdir(data_path)
    else
        local path_folder_name = manifest[path]
        if path_folder_name == nil then return end

        local path_folder =  data_path .. "/" .. path_folder_name
        local group_path =  path_folder .. "/" .. group
        local config_path = group_path .. "/" .. config .. ".json"

        --check if config file exists or is empty (contains profile: [], active: nil)
        local config_json = utils.safeJsonDecode(config_path)
        if
            config_json == nil
            or config_json.profiles == nil
            or next(config_json.profiles) == nil
        then
            utils.rm(config_path)
        end

        --delete group,path folder if it is empty
        pcall(vim.fn.delete, group_path, "d")
        pcall(vim.fn.delete, path_folder, "d")

        --if path folder is deleted, delete the manifest entry
        if vim.fn.isdirectory(path_folder) ~= 1 then
            manifest[path] = nil

            if next(manifest) == nil then
                utils.rm(data_path)
            else
                local manifest_file = io.open(manifest_path, "w")
                if manifest_file ~= nil then
                    manifest_file:write(vim.fn.json_encode(manifest))
                    manifest_file:close()
                else
                    error("unable to write to file: " .. manifest_path)
                end
            end
        end
    end
end

---saves to disk the data for the given group configuration
---must ensure that all parameters are correct before calling the function
---@param path path the path of the scope for the config
---@param group_name groupName the name of the group
---@param config_name configName the name of the group configuration to save
local function saveGroupConfig(path, group_name, config_name)
    local group_data_folder = queryManifest(path, true) .. "/" .. group_name
    utils.mkdir(group_data_folder)

    local config_path = group_data_folder .. "/" .. config_name .. ".json"

    ---@type file*?
    local config_file = io.open(config_path, "w")
    if config_file ~= nil then
        config_file:write(vim.fn.json_encode(config_data[path][group_name][config_name]))
        config_file:close()
    else
        error("Unable to save group config. Cannot write to file '" .. config_path .. "'.")
    end
end

function M.saveConfigs()
    if main_config.preserve == false then return end

    for _, mod in ipairs(director_state.modified) do
        saveGroupConfig(mod.path, mod.group, mod.config)
    end
    for _, mod in ipairs(director_state.modified) do
        attemptClean(mod.path, mod.group, mod.config)
    end
    director_state.modified = {}
end

---loads from disk the config data for the given group
---@param path path the name of the scope for the config
---@param group_name groupName the group for which to load configs
local function loadGroupConfigs(path, group_name)
    local group = main_config.actions[group_name]

    --skip the stress if theres nothing to load
    if group.config_types == nil or next(group.config_types) == nil then
        return
    end

    --find and ensure existence of data folder for group
    ---@type string?
    local data_folder = queryManifest(path, false)

    --if manifest file does not exist, at least initialize empty config in memory
    if data_folder == nil then
        for name, _ in pairs(group.config_types) do
            if config_data[path] == nil then config_data[path] = {} end
            if config_data[path][group_name] == nil then config_data[path][group_name] = {} end
            config_data[path][group_name][name] = { active = nil, profiles = {} }
        end
        return
    end

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

            --ensure config data is organized properly
            if config_data[path] == nil then config_data[path] = {} end
            if config_data[path][group_name] == nil then config_data[path][group_name] = {} end
            config_data[path][group_name][name] = { active = nil, profiles = {} }

            --load config profiles
            if config ~= nil and config.profiles ~= nil then
                for profile_name, profile in pairs(config.profiles) do
                    if not utils.isValidName(profile_name) then
                        print(
                            "Attempted to load profile with invalid name '" .. profile_name .. "'."
                            .. "Names may only contain alphanumeric characters, underscores, and spaces."
                        )
                    else
                        local updated_profile = isProfileValid(profile, group.config_types[name])
                        if updated_profile ~= nil then
                            config_data[path][group_name][name].profiles[profile_name] = updated_profile
                        else
                            print("Attempted to load invalid profile '"..profile_name.."'. Skipped.")
                        end
                    end
                end
            end

            --ensure active profile is still valid and load it if so
            if
                config ~= nil
                and type(config.active) == "string"
                and config_data[path][group_name][name].profiles[config.active] ~= nil
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
    M.saveConfigs()

    local cwd = getcwd()

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
    local path = director_state.file
    if path == nil or file_actions[director_state.file] ~= nil then return end

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
        if action_data[config_name].active == nil then
            out[config_name] = utils.getDefaultProfile(main_config.actions[group_name].config_types[config_name])
        else
            out[config_name] = action_data[config_name].profiles[action_data[config_name].active]
        end
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
            path = getcwd()
        end

        --generate bound options
        for _, action in pairs(action_data.bound) do
            --determine keymap callback
            ---@type function
            local callback
            if action.configs == nil or next(action.configs) == nil then
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
            if action.configs == nil or next(action.configs) == nil then
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
        width = { min = "30%" },
        height = { min = 5, max = "75%" },
        separator_align = longest_bind + #hyphen,
        next_bind = main_config.binds.down,
        previous_bind = main_config.binds.up,
        close_bind = main_config.binds.cancel,

        options = options
    }, true)

    --set keybinds
    for _, confirm_bind in pairs(main_config.binds.select) do
        p:setKeymap("n", confirm_bind, function()
            p:getOption().callback()
            p:close()
        end)
    end
    for bind, callback in pairs(bind_map) do
        p:setKeymap("n", bind, function()
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

    local file_path = director_state.file or ""
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
    local file_path = director_state.file or ""

    openActionsMenu(" Directory Actions ", cwd_actions, file_path)
end

---accesses all detected active file-specific actions
function M.fileMenu()
    local file_path = director_state.file or ""

    if vim.fn.filereadable(file_path) == 1 then
        openActionsMenu(" File Actions ", file_actions[file_path], file_path)
    else
        print("Director File Menu could not be opened for the current buffer as it is not associated with a file.")
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

    local file_path = director_state.file or ""
    if vim.fn.filereadable(file_path) == 1 then
        for name, group in pairs(file_actions[file_path]) do
            actions[name] = { bound = {}, unbound = {} }

            for bind, action in pairs(group.bound) do
                if cwd_bind_info[bind] == nil then
                    actions[name].bound[bind] = action
                else

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
            end

            for idx, action in pairs(group.unbound) do
                actions[name].unbound[idx] = action
            end
        end
    end

    openActionsMenu(" Actions ", actions, file_path)
end

---@type function, function, function, function
local configFieldMenu, configProfilesMenu, configProfileEditor

---opens the config menu for a specific field in a configuration
configFieldMenu = function(path, group, config, profile, field)
    ---@type ConfigField
    local desc
    do
        local fields = main_config.actions[group].config_types[config]
        for _, field_desc in pairs(fields) do
            if field_desc.name == field then
                desc = field_desc
                break
            end
        end
    end

    if desc.type == "string" then
        local p
        p = PromptPopup:new({
            text = {},
            prompt = "> ",
            title = " "..field.." ",
            verify_input = desc.validate,
            width = { min = 40, value = "50%" },
            close_bind = main_config.binds.cancel,
            on_confirm = function (text)
                config_data[path][group][config].profiles[profile][field] = text
                flagModified(path, group, config)
                p:close()
            end,
            on_close = function()
                configProfileEditor(path, group, config, profile)
            end
        }, true)

    elseif desc.type == "number" then
        local validate
        if desc.validate ~= nil then
            ---@param text string
            ---@return boolean
            validate = function(text)
                local num = tonumber(text)
                if num == nil then
                    print("Input should be a number. '"..text.."' is not a number.")
                    return false
                else
                    return desc.validate(num)
                end
            end
        else
            ---@param text string
            ---@return boolean
            validate = function(text)
                local num = tonumber(text)
                if num == nil then
                    print("Input should be a number. '"..text.."' is not a number.")
                    return false
                end
                return true
            end
        end

        local p
        p = PromptPopup:new({
            text = {},
            prompt = "> ",
            title = " "..field.." ",
            verify_input = validate,
            width = { min = 40, value = "20%" },
            close_bind = main_config.binds.cancel,
            on_confirm = function (text)
                config_data[path][group][config].profiles[profile][field] = tonumber(text)
                flagModified(path, group, config)
                p:close()
            end,
            on_close = function()
                configProfileEditor(path, group, config, profile)
            end
        }, true)

    elseif desc.type == "option" then
        ---@type string[]
        local options_raw
        if type(desc.default) == "function" then
            options_raw = desc.default()
        else
            options_raw = desc.default
        end

        ---@type Option[]
        local options = {}
        for _, option_text in pairs(options_raw) do
            table.insert(options, { text = option_text })
        end

        local p = OptionsPopup:new({
            options = options,
            title = " "..field.." ",
            width = { min = 40, value = "30%" },
            close_bind = main_config.binds.cancel,
            next_bind = main_config.binds.down,
            previous_bind = main_config.binds.up,
            height = { min = 5, max = "70%" },
            on_close = function()
                configProfileEditor(path, group, config, profile)
            end
        }, true)
        for _, bind in pairs(main_config.binds.select) do
            p:setKeymap("n", bind, function()
                config_data[path][group][config].profiles[profile][field] = p:getOption().text
                flagModified(path, group, config)
                p:close()
            end)
        end

    elseif desc.type == "list" then
        local p
        p = Popup:new({
            title = " "..field.." ",
            text = config_data[path][group][config].profiles[profile][field],
            width = { min = 40, value = "50%" },
            height = { min = 20, value = "50%" },
            modifiable = true,
            close_bind = main_config.binds.cancel,
            on_close = function()
                if p.write_autocmd ~= nil then
                    vim.api.nvim_del_autocmd(p.write_autocmd)
                    p.write_autocmd = nil ---@diagnostic disable-line:inject-field
                end
                configProfileEditor(path, group, config, profile)
            end
        }, true)
        vim.api.nvim_set_option_value("buftype", "acwrite", { buf = p:bufId() })
        vim.api.nvim_set_option_value("signcolumn", "yes", { win = p:winId() })
        vim.api.nvim_set_option_value("winhighlight", "Normal:Normal", { scope = "local", win = p:winId() })
        p.write_autocmd = vim.api.nvim_create_autocmd({ "BufWriteCmd" }, ---@diagnostic disable-line:inject-field
            {
                buffer = p:bufId(),
                callback = function()
                    local value = p:getText()
                    if desc.validate ~= nil and not desc.validate(p:getText()) then
                        print("Invalid value. Not saved.")
                        return
                    end
                    vim.api.nvim_set_option_value("modified", false, { buf = p:bufId() })
                    config_data[path][group][config].profiles[profile][field] = value
                    print("Saved.")
                    flagModified(path, group, config)
                end
            }
        )

    elseif desc.type == "boolean" then
        ---@type Option[]
        local options = { { text = "true", value = true }, { text = "false", value = false } }
        local p = OptionsPopup:new({
            options = options,
            title = " "..field.." ",
            width = { min = 40, value = "50%" },
            close_bind = main_config.binds.cancel,
            next_bind = main_config.binds.down,
            previous_bind = main_config.binds.up,
            height = { min = 5, max = "70%" },
            on_close = function()
                configProfileEditor(path, group, config, profile)
            end
        }, true)

        for _, bind in pairs(main_config.binds.select) do
            p:setKeymap("n", bind, function()
                config_data[path][group][config].profiles[profile][field] = p:getOption().value
                flagModified(path, group, config)
                p:close()
            end)
        end
    else
        error("Invalid field type '"..desc.type.."'.")
    end
end

---converts a config field type to its respective highlight group
---@param type ConfigFieldType
---@return string
local function typeToHl(type)
    if type == "number" then
        return "Number"
    elseif type == "boolean" then
        return "Boolean"
    else
        return "String"
    end
end

---opens the config menu for a specific profile
configProfileEditor = function(path, group, config, profile)
    local cfg = config_data[path][group][config].profiles[profile]
    local fields = main_config.actions[group].config_types[config]

    ---@type PreviewedOption[]
    local options = {}

    for _, field in pairs(fields) do
        table.insert(options, {
            text = field.name,
            preview = function(_)
                local value = cfg[field.name]

                if field.type == "list" then
                    local out = {}
                    for _, entry in ipairs(value) do
                        table.insert(out, Line("\""..tostring(entry).."\"", { hl_group = "String" }))
                    end
                    return out
                else
                    if field.type == "option" or field.type == "string" then
                        value = "\""..tostring(value).."\""
                    else
                        value = tostring(value)
                    end

                    return { Line(value, { hl_group = typeToHl(field.type) }) }
                end
            end,
            boolean = field.type == "boolean"
        })
    end

    local p = PreviewPopup:new({
        options_opts = {
            title = " "..profile.." Fields ",
            width = { min = 24, value = "20%" }
        },
        preview_opts = {
            title = " Value ",
            width = { min = 24, value = "30%" }
        },
        height = { min = 10, value = "40%" },
        options = options,
        next_bind = main_config.binds.down,
        previous_bind = main_config.binds.up,
        close_bind = {}
    }, true)

    for _, tbl in pairs({ main_config.binds.select, main_config.binds.edit }) do
        for _, bind in pairs(tbl) do
            p:setKeymap("n", bind, function()
                local opt = p:getOption()
                if opt.boolean then
                    cfg[opt.text] = not cfg[opt.text]
                    p:reloadPreview()
                    flagModified(path, group, config)
                else
                    configFieldMenu(path, group, config, profile, opt.text)
                    p:close()
                end
            end)
        end
    end
    for _, bind in pairs(main_config.binds.cancel) do
        p:setKeymap("n", bind, function()
            configProfilesMenu(path, group, config)
        end)
    end
end

---@param path string
---@param group string
---@param config string
---@param profile? string
---@param show_profile? boolean
---@return Line[]
local function configPreview(path, group, config, profile, show_profile)
    local profile = profile ---@diagnostic disable-line:redefined-local
    if
        config_data[path] == nil
        or config_data[path][group] == nil
        or config_data[path][group][config] == nil
    then
        error("Invalid config preview")
    end

    local cfg = config_data[path][group][config].profiles[profile]
    local fields = main_config.actions[group].config_types[config]

    local out

    if show_profile then
        if profile == nil then
            out = { Line("PROFILE: [DEFAULT]", { hl_group = "PreProc"} ) }
        else
            out = { Line("PROFILE: "..profile, { hl_group = "PreProc"} ) }
        end
    else
        out = {}
    end

    if profile == nil then
        for _, field in pairs(fields) do
            local value
            if type(field.default) == "function" then
                value = field.default()
            else
                value = field.default
            end

            if field.type == "list" then
                table.insert(out, Line({
                    Text(field.name, { hl_group = "Identifier" }),
                    Text(":", { hl_group = "Operator" })
                }))
                for _, entry in ipairs(value) do
                    table.insert(out, Line("\t\""..tostring(entry).."\"", { hl_group = "String" }))
                end
            else
                if field.type == "option" then
                    value = "\""..tostring(value[1]).."\""
                elseif field.type == "string" then
                    value = "\""..value.."\""
                else
                    value = tostring(value)
                end

                table.insert(out, Line({
                    Text(field.name, { hl_group = "Identifier" }),
                    Text(":", { hl_group = "Operator" }),
                    Text(" "..value, { hl_group = typeToHl(field.type) }),
                }))
            end
        end

    else
        for _, field in pairs(fields) do
            local value = cfg[field.name]

            if field.type == "list" then
                table.insert(out, Line({
                    Text(field.name, { hl_group = "Identifier" }),
                    Text(":", { hl_group = "Operator" })
                }))
                for _, entry in ipairs(value) do
                    table.insert(out, Line("\t\""..tostring(entry).."\"", { hl_group = "String" }))
                end
            else
                if field.type == "string" or field.type == "option" then
                    value = "\""..value.."\""
                else
                    value = tostring(value)
                end

                table.insert(out, Line({
                    Text(field.name, { hl_group = "Identifier" }),
                    Text(":", { hl_group = "Operator" }),
                    Text(" "..value, { hl_group = typeToHl(field.type) }),
                }))
            end
        end
    end

    return out
end

local function newProfileMenu(path, group, config)
    local p
    p = PromptPopup:new({
        text = {
            Line("Enter a name for your new profile.", { align = "center" }),
            Line("Names may only contain alphanumeric", { align = "center" }),
            Line("characters, spaces, and underscores", { align = "center" }),
            ""
        },
        prompt = "> ",
        title = " New Profile ",
        verify_input = function(name)
            if utils.isValidName(name) then
                if config_data[path][group][config].profiles[name] == nil then
                    return true
                else
                    print("A profile named '"..name.."' already exists.")
                    return false
                end
            else
                print("Name '"..name.."' is invalid.")
                return false
            end
        end,
        width = { min = 20, value = "30%" },
        close_bind = main_config.binds.cancel,
        on_confirm = function (name)
            config_data[path][group][config].profiles[name] = utils.getDefaultProfile(
                main_config.actions[group].config_types[config]
            )
            flagModified(path, group, config)
            p:close()
        end,
        on_close = function()
            configProfilesMenu(path, group, config)
        end
    }, true)
end

local function deleteProfileMenu(path, group, config, profile)
    local first_line = "  Are you sure you want to delete '"..profile.."'?"
    local width = #first_line + 2

    local p = Popup:new({
        width = width,
        text = {
            first_line,
            Line("This action cannot be undone.", { hl_group = "DiagnosticError", align = "center"}),
            "",
            Line(
                {
                    Text("Yes - [y/Y]", { hl_group = "DiffAdd" }),
                    Text("        "),
                    Text("No - [n/N]", { hl_group = "DiffDelete" })
                },
                { align = "center" }
            )
        },
        title = " Delete Profile ",
    }, true)

    for _, bind in pairs({ "y", "Y" }) do
        p:setKeymap("n", bind, function()
            local cfg = config_data[path][group][config]
            if cfg.active == profile then
                cfg.active = nil
            end
            cfg.profiles[profile] = nil
            flagModified(path, group, config)

            configProfilesMenu(path, group, config)
            p:close()
        end)
    end
    for _, tbl in pairs({ main_config.binds.cancel, { "n", "N" } }) do
        for _, bind in pairs(tbl) do
            p:setKeymap("n", bind, function()
                configProfilesMenu(path, group, config)
                p:close()
            end)
        end
    end
end

local function renameProfileMenu(path, group, config, profile)
    local p
    p = PromptPopup:new({
        text = {
            Line("Enter a new name for "..profile..".", { align = "center" }),
            Line("Names may only contain alphanumeric", { align = "center" }),
            Line("characters, spaces, and underscores", { align = "center" }),
            ""
        },
        prompt = "> ",
        title = " Rename Profile ",
        verify_input = function(name)
            if utils.isValidName(name) then
                if config_data[path][group][config].profiles[name] == nil then
                    return true
                else
                    print("A profile named '"..name.."' already exists.")
                    return false
                end
            else
                print("New name '"..name.."' is invalid.")
                return false
            end
        end,
        width = { min = 20, value = "30%" },
        close_bind = main_config.binds.cancel,
        on_confirm = function (name)
            config_data[path][group][config].profiles[name] = config_data[path][group][config].profiles[profile]
            config_data[path][group][config].profiles[profile] = nil
            flagModified(path, group, config)
            p:close()
        end,
        on_close = function()
            configProfilesMenu(path, group, config)
        end
    }, true)
end

---opens the config menu for a specific configuration, listing available profiles
configProfilesMenu = function(path, group, config)
    local cfg = config_data[path][group][config]

    ---@type PreviewedOption[]
    local options = {
        {
            preview = function(_)
                return configPreview(path, group, config, nil, false)
            end,
        }
    }
    if cfg.active == nil then
        options[1].text = "* [DEFAULT]"
    else
        options[1].text = "  [DEFAULT]"
    end

    for name, _ in pairs(cfg.profiles) do
        local text
        if cfg.active == name then
            text = "* "..name
        else
            text = "  "..name
        end
        table.insert(options, {
            text = text,
            preview = function(_)
                return configPreview(path, group, config, name, false)
            end,
            profile = name
        })
    end

    local p = PreviewPopup:new({
        options_opts = {
            title = " "..config.." Profiles ",
            width = { min = 20 }
        },
        preview_opts = {
            title = " Profile Data ",
            width = { min = 24, value = "50%" }
        },
        height = { min = 10, value = "70%" },
        options = options,
        next_bind = main_config.binds.down,
        previous_bind = main_config.binds.up,
        close_bind = {}
    }, true)

    for _, bind in pairs(main_config.binds.edit) do
        p:setKeymap("n", bind, function()
            local opt = p:getOption()
            if opt.profile == nil then
                print("You may not edit defaults.")
            else
                configProfileEditor(path, group, config, opt.profile)
                p:close()
            end
        end)
    end
    for _, bind in pairs(main_config.binds.new) do
        p:setKeymap("n", bind, function()
            newProfileMenu(path, group, config)
            p:close()
        end)
    end
    for _, bind in pairs(main_config.binds.select) do
        p:setKeymap("n", bind, function()
            local option = p:getOption()
            if cfg.active == option.profile then return end

            for _, opt in ipairs(options) do
                if string.sub(opt.text, 1, 1) == "*" then
                    opt.text = " "..string.sub(opt.text, 2)
                    break
                end
            end
            option.text = "*"..string.sub(option.text, 2)
            cfg.active = option.profile
            flagModified(path, group, config)
            p:refreshText()
        end)
    end
    for _, bind in pairs(main_config.binds.rename) do
        p:setKeymap("n", bind, function()
            local opt = p:getOption()
            if opt.profile == nil then
                print("You may not rename defaults.")
            else
                renameProfileMenu(path, group, config, opt.profile)
                p:close()
            end
        end)
    end
    for _, bind in pairs(main_config.binds.delete) do
        p:setKeymap("n", bind, function()
            local opt = p:getOption()
            if opt.profile == nil then
                print("You may not delete defaults.")
            else
                deleteProfileMenu(path, group, config, opt.profile)
                p:close()
            end
        end)
    end
    for _, bind in pairs(main_config.binds.cancel) do
        p:setKeymap("n", bind, function()
            M.configMenu()
        end)
    end
end

---accesses mainMenu action configurations
function M.configMenu()
    ---@type PreviewedOption[]
    local options = {}

    local dir_path = getcwd()
    local file_path = director_state.file or ""

    local all_titles = true

    local append_configs = function(path)
        if config_data[path] == nil then return end

        for group_name, config_list in pairs(config_data[path]) do
            table.insert(options, {
                text = group_name,
                is_title = true,
                preview = {}
            })

            for config_name, _ in pairs(config_list) do
                all_titles = false
                table.insert(options, {
                    text = config_name,
                    preview = function(_)
                        return configPreview(path, group_name, config_name, nil, true)
                    end,
                    path = path,
                    group = group_name,
                    config = config_name
                })
            end
        end
    end
    append_configs(dir_path)
    append_configs(file_path)

    if all_titles then
        print("No actions are configurable in this context.")
        return
    end

    local p = PreviewPopup:new({
        options_opts = {
            title = " Configurations ",
            width = { min = 20 }
        },
        preview_opts = {
            title = " Active Configuration ",
            width = { min = 24, value = "50%" }
        },
        height = { min = 10, value = "70%" },
        options = options,
        next_bind = main_config.binds.down,
        previous_bind = main_config.binds.up,
        close_bind = main_config.binds.cancel
    }, true)

    for _, tbl in pairs({ main_config.binds.select, main_config.binds.edit }) do
        for _, bind in pairs(tbl) do
            p:setKeymap("n", bind, function()
                local opt = p:getOption()
                configProfilesMenu(opt.path, opt.group, opt.config)
                p:close()
            end)
        end
    end
end

--todo:
--  - use oneup line and text classes to make config menus more pretty

return M
