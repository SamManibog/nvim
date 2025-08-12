# API Reference

Top-level Directory API reference.

## Functions

### setup(opts)

Setup function for the plugin. Must be called before using any other top-level API call.

*See Configuration.md for more information.*

### saveConfigs()

Force-saves all created configuration profiles in the current session. This is called automatically when
Neovim exits or the current working directory is changed. Does nothing if disk saves are disabled.

### refreshCwdActions()

Force-reloads all current working directory actions after first saving the previously loaded actions.
This is called automatically when opening Neovim and when the current working directory changes.

### loadFileActions()

Loads all actions associated to the current file. This is called automatically whenever your current buffer
changes to a file. File actions are unloaded when the current working directory changes.

### directoryMenu()

Opens a context menu where all actions valid for the current working directory may be accessed and used.

### fileMenu()

Opens a context menu where all actions valid for the current file buffer may be accessed and used.

### mainMenu()

Opens a context menu where all actions valid for the current file buffer and working directory
may be accessed and used.

### quickMenu()

Like mainMenu(), but only actions with keybinds (and highest priority for that keybind) may be
accessed and used.

*See Configuration.md for more information on action priorities.*

### configMenu()

Opens a menu where action configuration presets may be selected and edited.

*See Configuration.md for more information on writing configurable actions.*

### runAction(group, desc, silent)

Runs the specified action in the current context (current file or working directory, and active configuration presets).

*Parameters:*
- `string` group - The group that the action belongs to.
- `string` desc - The description of the action (must be an exact match).
- `boolean` silent - Whether a message should be printed upon failing to run an action.

