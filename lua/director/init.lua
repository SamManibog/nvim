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
---@field name string                   The name of the action group
---@field detect fun(): boolean         A function that determines if the actions in the group should be loaded
---@field actions ActionDescriptor[]    A list of actions belonging to the group
---@field config_types table<string, ConfigDescriptor>? a map defining names for config types, allowing them to be reused but work as configs for separate actions

---@class DirectorConfig
---@field preserve boolean                  whether or not to save in-editor configuration to disk
---@field binds DirectorBindsConfig         binds for menus
---@field cwd_actions ActionGroup[]    a list of actions that may be used local to the cwd
---@field file_actions ActionGroup[]   a list of actions that may be used local to the current file

---@alias bind string
---@alias path string

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

---refresh actions for the cwd

M.setup({
    ---@type ActionGroup[]
    cwd_actions = {
        require("director.actions.cargo"),
        require("director.actions.cmake"),
    }
})

return M
