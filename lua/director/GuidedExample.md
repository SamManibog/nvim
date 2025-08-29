# Configuration Guided Example

So you need more than API-level documentation to get started with Director? Don't sweat it. This
guide is made for you!

## First Steps

The first thing you will need to write is a detection function. Let's assume you work frequently with Rust
and Cargo.

```lua
require("director").setup({
    disk_saves = true, -- I want to save my configs/presets to disk (we will learn how to use those later)
    binds = { -- Director's default bindings are often good enough, but I want to be able to open menus with a keystroke
        quick_menu = "<leader>mq",
        main_menu = "<leader>mm",
        config_menu = "<leader>mc",
    },
})
```

Opening Director's menus quickly is great and all, but they are useless without actions. Let's add our first
action group. For the sake of the example, we'll say that this action group is used to target Cargo buildsystems.

```lua
require("director").setup({
    disk_saves = true,
    binds = {
        quick_menu = "<leader>mq",
        main_menu = "<leader>mm",
        config_menu = "<leader>mc",
    },
    actions = {
        cargo = {}
    }
})
```

We now have an action group, but it is missing an important field: the detect function.
The detect function tells cargo when to load which action groups and is required to be implemented in every
action group.

Because we are targetting Cargo, there is an easy way to detect when a directory belongs to our buildsystem:
the existence of a *Cargo.toml* file at the top level.

```lua
cargo = {
    detect = function()
        return vim.fn.filereadable(vim.fn.getcwd().."/Cargo.toml") == 1
    end
}
```

There are two things to note here. The first is that the detect function takes no parameters, so
`vim.fn.getcwd()` and `vim.fn.expand("%")` should be used if you want to access the working directory or
current buffer's path. The second is that the detect function must have a boolean return type. Many of
vim's builtin functions may use 1 or 0 inplace of true or false, so be careful when using them, or your
action group may not be detected properly.

Great! Director now know when to load our action group, but there's one glaring problem: there are no actions
to load.

Let's add two actions: one to compile and another to run the project. Cargo is easy to use so the implementation
is trivial.

```lua
-- Director ships with its own utils, see Utils.md
local utils = require("director.utils")
...
cargo = {
    detect = function()
        return vim.fn.filereadable(vim.fn.getcwd().."/Cargo.toml") == 1
    end
    actions = {
        {
            bind = "c", -- Lets bind this action so that it can be used quickly
            desc = "Compile", -- We must set a description for each action
            callback = function() utils.runInTerminal("cargo build") end
        },
        {
            bind = "r",
            desc = "Run", -- Same here
            callback = function() utils.runInTerminal("cargo run") end
        },
    }
}
```

Congratulations! You've just written your first action group. Pretty painless right? But before you close the docs,
just one quick caveat with Director's `runInTerminal()` function: the terminal opened is persistent. Even when all
windows containing the terminal are closed, the buffer won't be deleted. You must use the `forceKillTerminal()`
function to remove it.


## Adding ConfigTypes

In the previous section, we created a basic actions group for the Cargo buildsystem. We will expand upon that
example by adding configution types. This will allow us to change the behavior of our actions at runtime without
having to modify our config.

ConfigTypes are added with the `config_types` field, a table assigning names to lists of ConfigFields.

Lets start by adding a ConfigType for code compilation. Perhaps we'll use it to specify our flags for build command.
To keep it simple, lets just have ConfigFields for compiling a release build and for specifying active Features.
For those not familiar with Rust, Features are basically values that can be specified at compile time to control
which code is compiled. Our action group now becomes:

```lua
cargo = {
    detect = function()
        return vim.fn.filereadable(vim.fn.getcwd().."/Cargo.toml") == 1
    end
    actions = {
        {
            bind = "c",
            desc = "Compile",
            callback = function() utils.runInTerminal("cargo build") end
        },
        {
            bind = "r",
            desc = "Run",
            callback = function() utils.runInTerminal("cargo run") end
        },
    },
    config_types = {
        compile = {
            {
                name = "Release",
                type = "boolean",
                default = false,
            },
            {
                name = "Features",
                type = "list",
                default = {},
            },
        },
    }
}
```

Thats all! Make sure that when writing a ConfigField, you include the three fields used above,
name to specify the field's displayed name, type to specify the accepted value types, and default to specify
the default value.

Valid types for a ConfigField are: "boolean", "string", "number", "list" (of strings), and "option". We will go over what
"option" is used for in a later section.

So now we have ConfigTypes, but how do we use them? We just ask for them of course. Here is what that would look like:

```lua
actions = {
    {
        bind = "c",
        desc = "Compile",
        configs = { "compile" }, -- This field is used to specify a list of required ConfigTypes for the action's callback
        callback = function(config)
            -- Let's create the build command from our config
            local command = "cargo build"

            if config.compile.Release == true then
                command = command.." -r" -- Release builds are specified with the -r flag
            end
            if #config.compile.Features > 0 then
                command = command.." -f"
                for _, feature in pairs(config.compile.Features) do
                    command = command.." "..feature -- Features can be specified with a space-delimited list
                end
            end

            utils.runInTerminal(command)
        end
    },
    {
        bind = "r",
        callback = function() utils.runInTerminal("cargo run") end
    },
}
```

The code may be more complicated than previous examples, but fortunately director contributes little complexity.

However, it is important to note that the whenever the `configs` field is specified, the callback must be able to
handle a table of values. Each key in that table will be an exact match to the specified configs.
Make sure that the names of the required ConfigTypes are an contained in the `config_types` field of the ActionGroup.
Also, multiple ConfigTypes may be accessed by an action, and ConfigTypes may also be shared between actions.

ConfigFields may be accessed using their exact name from their corresponding ConfigField as pictured above.

## Command Generation Basics

Often, actions will be used to run a command from the terminal, and their included ConfigTypes may be very long,
making it tedious to implement command creation functions such as the one in the previous section. Again, Director's
utils come to the rescue with the `generateCommand()` function. However, we will have to perform some minor refactoring.

The first thing we will need to do is separate the `config_types` field into its own variable. This will allow us to pass
it to `generateCommand()`.

```lua
local config_types = {
    compile = {
        {
            name = "Release",
            type = "boolean",
            default = false,
        },
        {
            name = "Features",
            type = "list",
            default = {},
        },
    },
}

cargo = {
    ...
    actions = {
        {
            bind = "c",
            desc = "Compile",
            configs = { "compile" },
            callback = function(config)
                utils.runInTerminal(
                    utils.generateCommand(
                        "cargo", -- First, pass the command name
                        config.compile -- Second, pass the configuration table
                        config_types.compile -- Finally, pass the corresponding list of ConfigFields
                    )
                )
            end
        },
        {
            bind = "r",
            callback = function() utils.runInTerminal("cargo run") end
        },
    },
    config_types = config_types
}
```

Unfortunately, this is not yet enough for our action to do something meaningful. We must first tell Director
how to parse the raw data. This is accomplished within our new `config_types` variable.

```lua
local config_types = {
    compile = {
        {
            name = "Release",
            type = "boolean",
            default = false,
            arg_prefix = "-r",
            bool_display = true, -- Display arg_prefix only when Release is true
        },
        {
            name = "Features",
            type = "list",
            default = {},
            arg_prefix = "-f" -- Prefix the list of features with -f
        },
    },
}
```

Our action will now work as intended.

There are a myriad of other fields in a ConfigField that can be used to work with `generateCommand()`, but fear not; we will
go through examples with each of them. But first, let me introduce you to a new ConfigField type.

## The Option Type

Recall that the valid types for a ConfigField are: "boolean", "string", "number", "list", and "option". The first four
are self-explanatory, but "option" will need a little bit more explanation.

At its core, option represents a string value. But rather than allow the user to type any string they please,
they must choose one out of a selection of possible options.

To illustrate this, let's create a new ConfigField. We'll use this one to specify another one of Cargo's build flags:
message format.

The message format flag is used to specify the output format for diagnostic messages. There are only a few valid arguments
for this flag, so the option type is the perfect fit. Here's what the implementation would look like:

```lua
compile = {
    ...
    {
        name = "Message Format",
        type = "option",
        default = "human",
        options = {
            "short",
            "human",
            "json",
            "json-diagnostic-short",
            "json-diagnostic-rendered-ansi",
            "json-render-diagnostics",
        },
        arg_prefix = "--msg-format",
        omit_default = true,
    },
}
```

In this snippet, we introduce two new fields: `options` and `omit_default`.

`options` is a required field whenever `type` is set to `"option"`. It can either be a list of strings,
or a function that returns a list of strings.

`omit_default` is another field that interacts with `generateCommand()`. Whenever the config's value matches
the default value, the associated flag is not added to the generated command.

end
