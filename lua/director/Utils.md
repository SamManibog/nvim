# Utilities API Reference

Utils module API reference.

## Functions

### safeJsonDecode(path) -> any

Decodes the Json file at the given path. Returns nil if the file could not be accessed or decoded properly.

### generateCommand(head, config, fields)

Generates a shell command based on a configuration preset.

*Parameters:*
- `string` head - The first part of the command (executable name)
- `table` config - The configuration specification to use *(See Configuration.md)*
- `table[]` - A list of configuration options specified *(See Configuration.md)*

*return (`string`):* The shell command generated.

### mkdir(path)

Makes a directory with the given path. Unlike the builtin vim.uv.fs_mkdir, first checks
if the directory exists before creation and will silently fail if so (avoiding an annoying error message).

### listFiles(path, detect, whitelist, depth, count) -> string[]

Lists the paths of all files and directories satisfying the given callback using a breadth first search.

*Parameters:*
- `string` path - The root directory to begin searching from.
- `function(string) -> boolean` detect - The callback used to detect if a given path should be returned.
- `nil` or `function(string) -> boolean` whitelist - The optional callback used to determine if a given directory should be searched.
- `nil` or `integer` depth - The maximum depth to search for files. 0 means only the given path will be checked.
- `nil` or `integer` count - The maximum number of paths to return.

*return (`string[]`):* A list of files satisfying the detect function.

### openTerminal(name) -> boolean

Opens a terminal buffer split from the bottom of the current window. This terminal buffer
is not deleted automatically, so calling openTerminal() with the same name argument will open the
same terminal.

*Parameters:*
- `string` name - The name of the associated terminal. Defaults to `"default"`.

*return (boolean):* Returns true if a new terminal buffer was created. Returns false if
the terminal buffer already exists.

### forceKillTerminal(name)

Kills the terminal buffer created by a call to openTerminal(). Calling openTerminal() again
will open a new terminal buffer.

*Parameters:*
- `string` name - The name of the terminal to kill. Defaults to `"default"`.

### terminalIsOpen(name) -> boolean

Checks if the terminal buffer created by calling openTerminal() is active.
Note that the buffer may be active without being visisble on any window.

*Parameters:*
- `string` name - The name of the terminal to check. Defaults to `"default"`.

*return (boolean):* Returns true if Director's terminal buffer exists and false otherwise.

### runInTerminal(cmd, name, silent)

Stops the current job running in the specified terminal buffer, and runs a new job.
If the terminal has not been previously opened, a new terminal is created first via openTerminal().

*Parameters:*
- `string` cmd - The command to run in the terminal.
- `string` name - The name of the terminal to run the command in. Defaults to `"default"`.
- `boolean` silent - An optional parameter that when set to true will not open a window with the given terminal. In essence, it will run the command in the background.

### toggleTerminal(name)

If the current buffer is ANY terminal buffer, closes the associated window,
otherwise opens a possibly new terminal with the associated name via openTerminal().

*Parameters:*
- `string` name - The name of the terminal to possibly open. Defaults to `"default"`.
