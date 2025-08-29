# Director Configuration

Advanced Director configuration guide.

## Basic Setup Options

There are 3 main setup options for director. This one covers the most basic ones,
however director's functionality comes from the setup options detailed in the
next section, *Actions*.

### Disk Saves

disk_saves is an optional boolean value (false by default), that allows director
to save presets (see *Understanding Director* in *README.md*) to the disk.
Disk saves write to the director subdirectory in neovim's data folder.

## Binds

binds is a table value consisting of a string key and a list or string value pairs.
Binds settings are used for navigating director's various menus. The defaults can be
viewed at *defaults.lua*.

Here are each of the binds and what they are used for (see *Understanding Director* in *README.md*
for menu definitions):
- up - Go up an option or entry.
- down - Go down an option or entry.
- cancel - Return to the previous menu or close if there is none.
- select - Select an option or entry. In the fields menu, edits the field.
- edit - Edit an option or entry.
- new - When in the preset menu, create a new preset.
- rename - When in the preset menu, rename an existing preset.
- delete - When in the preset menu, delete an existing preset.
- quick_menu - Open the quick menu.
- directory_menu - Open the directory menu.
- file_menu - Open the file menu.
- main_menu - Open the main menu.
- config_menu - Open the configurations menu.

## Actions

actions is the configuration option at the heart of Director.
It is a map from string name to an ActionGroup.

### ActionGroups

An action group is table containing a collection of actions that are loaded when some user-defined conditions
are met. Actions within the same group are able to share data between each other via configs.

#### file_local

*Type:* `bool`

Defines whether the action group is loaded for individual files or
for the current working directory.

#### detect

*Type:* `function() -> bool`

The function used to detect if an action group is relevant in the given context. It is recommended to
use `vim.fn.expand("%")` or `vim.fn.getcwd()` within the function to get the buffer and working directory,
respectively.

#### actions

Type: `ActionDescriptor[]`

A list of actions belonging to the action group. ActionDescriptors are detailed in an upcoming section.

#### config_types

Type: `table<string, ConfigField[]>`

A table of configs belonging to the action group. Configs can be shared across actions within the same group.
Configs types are defined by a name (the key of the table) and a list of ConfigFields (the value of the table)
which define the configurable options in a config type. ConfigFields are detailed in an upcoming section.

#### priority

*Type:* `number`

When actions are be assigned keybinds, priority is used to determine which action is used when actions from
other groups have duplicate binds. The priority of an action group is the default priority of all bound actions.

### ActionsDescriptors

An action descriptor is a table of values most notably containing a function which can be ran from an
actions menu.

#### desc

*Type:* `string`

The written description of the action in actions menus. Actions within the same group should not have
the same description (not enforced).

#### bind

*Type:* `string?`

An optional keybind for the action. Keybinds allow actions to be called quickly from actions menus, and are
required for them to appear in the quickmenu.

#### priority

*Type:* `number`

When actions are be assigned keybinds, priority is used to determine which action is used when actions from
other groups have duplicate binds.

#### configs

*Type:* `string[]?`

A list of config types names from the action group (the config_types field) that are used by this action.
Remember, config types are simply lists of ConfigFields, which will be described in-depth in a later section.

#### callback

*Type:* `function()` or `function(ActionConfig)`

The function to run when this action is selected from an actions menu. The required type changes depending
on the value of configs. If configs is `nil`, then the type is `function()` and the action is run without 
any configuration. If configs is a list of strings, then the type is `function(ActionConfig)`.

### ActionConfig

ActionConfig is an alias for `table<string, table<string, any>>` where the first string is the name
of a ConfigType, and the next string is the name of a ConfigField from that type. The deepest value
is specified by the user or loaded from the disk at runtime.

### ConfigFields

ConfigFields are tables that define which values and data types are valid for a given field in a preset.
They dictate what data is passed to Actions using its parent ConfigType.

#### name

*Type:* `string`

The name of the config field ("second string" of an ActionConfig).

#### type

*Type:* `string`

The type that the config field may hold. There are only a few valid values for this field:
- "string" - a string value
- "number" - a number value
- "boolean" - a boolean value
- "option" - one (string) option from a provided list of options
- "list"   - a list of strings

#### default

*Type:* `any`

The default value of the config field. This must match the type field. A function taking no parameters and
returning a value whose type matches the type field is also valid.

#### validate

*Type:* `function(any) -> boolean`

An optional field that may be used to validate a proposed value for a config field before it is saved.
The value passed to the function will match the type field.

#### options

Type: `string[]` or `function() -> string[]`

If type is "option" then this provides the possible options that may be selected from.

#### Advanced Options

ConfigFields also have special options that are used in the `generateCommand()` function (see *Utils.md*).
These fields are used to define how a ConfigType is converted to a command. Note that all of these fields
are optional.

- cmd_omit (`boolean`) - If true, the field is not used when generating a command.
- omit_default (`boolean`) - If true, when the value is the same as the default, this field is omitted.
- arg_prefix (`string`) - When defined, the string used to prefix the field's value. Note that a space is automatically inserted before each new field.
- arg_postfix (`string`) - When defined, the string used to postfix the field's value.
- list_affix (`boolean`) - When true, every element in the list will be surrounded by arg_prefix/postfix. Otherwise, arg_prefix and postfix surround all list entries.
- bool_display (`boolean`) - When non nil and the field's value is a boolean, adds arg_prefix to the command when the field's value and this value match.
- custom_cmd (`fun(any): string`) - If defined, the field's value is passed to the function before being added to the list. Note that arg_prefix/postfix will surround the return value.
