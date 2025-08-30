# Director

Director is an action/task management system designed to be intuitive and highly configurable.

Notable features include:
- Defining custom actions via Lua
- A library of relevant utility functions for use in code actions
- The ability to easily define presets for actions at runtime
- Saving action presets to disk
- Context menus for directory actions, file actions, and the customization of each

*Note that because of Director's design philosophy, very little out-of-the-box
functionality exists. Effective use of this plugin revolves around your implementation of code actions.
See Configuration.md and GuidedExample.md to learn how to write your own actions. You may also use my
[Neovim configuration](https://github.com/SamManibog/nvim/tree/main/lua/director_configs) for reference.*

## Installation

## Usage Guide

### Setup

Before using Director, the setup() function must first be called with your settings
as arguments. See *defaults.lua* for the default settings, and *Configuration.md* for 
an exhaustive list of settings.

```lua
local Director = require("director")

Director.setup({
    disk_saves = true,  -- Enable saving configured actions to disk
    binds = {   -- A list of keybinds for the plugin
        new =           "n", -- Create a new configuration preset
        rename =        "r", -- Rename an existing configuration preset
        delete =        { "d", "D" }, -- Delete an action preset
        edit =          { "e", "E" }, -- Edit an existing option
        quick_menu =    "<leader>q",
        config_menu =   "<leader>c",
    },
    actions = {...} -- This field is required. See Configuration.md for instructions on how to use this field.
})
```

### Understanding Director

Actions performed through Director are interacted with mainly through 2 types of menus:
action menus and edit menus.

The contents of each menu are defined by your current working directory and current file buffer.
(See *Configuration.md* to learn how to specify which actions show up in which contexts).

Action menus are simple. You can navigate up or down to the desired action and run it using the select keybind,
or you can define custom keybinds to quickly call them from an action menu. In the case that multiple actions
are mapped to the same keybind, the one with the highest priority is used. (See *Configuration.md* for more
information on keybinds.)

There are four different action menus:
- The main menu which lists all valid actions in the given context
- The file menu which lists all valid actions for the current buffer
- The directory menu which lists all valid actions for the working directory
- The quick menu which lists all valid actions in the given context that have been asigned keybinds

Edit menus are a bit more complex to use, and are all submenus of the configurations menu.

Using the select keybind on a configuration in the configurations menu will open the
presets menu for that configuration.

The Presets menu is the most complex of the edit menus. From here you can
use your new, rename, and delete keybinds on presets in this menu.
You may also use the select keybind to set the active preset for the configuration.
Using the edit keybind will allow you to modify the fields in the preset from the
fields menu.

The fields menu is simple to use. Using the select or edit keybinds on this will
allow you to edit the values for each field via a separate submenu which should be self explanatory to use.
The only submenu that may be confusing to use is the list edit submenu. List items can be entered on separate
lines. You can save your changes sing the write command (*:w*). Closing the menu will then reopen the fields menu.

### The Director Command

Director defines one user command *Director* which can be used to open any Director menu.
The command can be run with any of the following arguments:
-  (q) - to list all commands with keybinds
-  (m) - to list all loaded commands
-  (d) - to list all working directory commands
-  (f) - to list all file commands
-  (c) - to open the configuration menu
-  (s) - to force save all configuration changes
- (rf) - to force reload all file actions
- (rd) - to force reload all directory actions
- (rr) - to force reload all actions
