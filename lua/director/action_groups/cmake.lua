local utils = require("director.utils")

local basic_user_presets = [[{
    "version": 10,
    "configurePresets": [
        {
            "name": "debug",
            "generator": "MinGW Makefiles",
            "cacheVariables": {
                "CMAKE_C_COMPILER": "gcc",
                "CMAKE_CXX_COMPILER": "g++",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
            }
        }
    ]
}]]

---lists all built executables relative to the build folder
---@return string[]
local function listBuiltExes()
    return utils.listFiles(
        vim.fn.getcwd().."/build",
        function (path)
            return vim.fn.executable(path) == 1
        end,
        function (path)
            local name = vim.fn.fnamemodify(path, ":t")
            return name ~= "CMakeFiles" and name ~= ".cmake" and name ~= "Testing"
        end,
        8
    )
end

---@type table<string, ConfigField[]>
local config_types = {
    initialize = {
        {
            name = "Preset",
            type = "string",
            default = "debug",
            arg_prefix = "preset="
        },
        {
            name = "Generator",
            type = "string",
            default = "MinGW Makefiles",
            arg_prefix = "-G "
        },
        {
            name = "Toolset Spec",
            type = "string",
            default = "",
            arg_prefix = "-T "
        },
        {
            name = "Platform Name",
            type = "string",
            default = "",
            arg_prefix = "-A "
        },
        {
            name = "Toolchain",
            type = "string",
            default = "",
            arg_prefix = "--toolchain "
        },
        {
            name = "Install Prefix",
            type = "string",
            default = "",
            arg_prefix = "--install-prefix "
        },
        {
            name = "Log Level",
            type = "option",
            default = "STATUS",
            options = {
                "ERROR",
                "WARNING",
                "NOTICE",
                "STATUS",
                "VERBOSE",
                "DEBUG",
                "TRACE"
            },
            omit_default = true,
            arg_prefix = "--log-level="
        },
        {
            name = "Other Args",
            type = "list",
            default = {},
            arg_prefix = " "
        }
    },
    compile = {
        {
            name = "Preset",
            type = "string",
            default = "",
            arg_prefix = "--preset="
        },
        {
            name = "Targets",
            type = "list",
            default = {},
            arg_prefix = "-t"
        },
        {
            name = "Clean First",
            type = "boolean",
            default = false,
            bool_display = true,
        },
        {
            name = "Verbose",
            type = "boolean",
            default = false,
            bool_display = true
        },
        {
            name = "Resolve References",
            type = "option",
            default = "on",
            options = { "on", "only", "off" },
            omit_default = true,
            arg_prefix = "--resolve-package-references"
        },
        {
            name = "Parallel Jobs",
            type = "number",
            default = 0,
            validate = function(num)
                local out = math.floor(num) == num and num >= 0
                if out == false then
                    print("Value must be a non-negative integer. 0 signifies use of native default.")
                end
                return out
            end,
            omit_default = true,
            arg_prefix = "-j "
        },
        {
            name = "Build Tool Args",
            type = "list",
            default = {},
            arg_prefix = " --",
        },
    },
    run = {
        {
            name = "Target",
            type = "option",
            default = "",
            options = function()
                local out = listBuiltExes()
                if #out <= 0 then
                    print("No executables found in build folder. Try compiling one first.")
                    return { "" }
                else
                    return out
                end
            end,
            arg_prefix = "\"./build",
            arg_postfix = "\""
        },
        {
            name = "Arguments",
            type = "list",
            default = {},
        }
    },
    test = {
        {
            name = "Preset",
            type = "string",
            default = "",
            arg_prefix = "--preset="
        },
        {
            name = "Progress Messages",
            type = "boolean",
            default = false,
            arg_prefix = "--progress",
            bool_display = true
        },
        {
            name = "Parallel Jobs",
            type = "number",
            default = 0,
            validate = function(num)
                local out = math.floor(num) == num and num >= 0
                if out == false then
                    print("Value must be a non-negative integer. 0 signifies use of native default.")
                end
                return out
            end,
            arg_prefix = "-j ",
            omit_default = true
        },
        {
            name = "Test Load",
            type = "number",
            default = 0,
            validate = function(num)
                local out = math.floor(num) == num and num >= 0
                if out == false then
                    print("Value must be a non-negative integer. 0 signifies default.")
                end
                return out
            end,
            arg_prefix = "--test-load ",
            omit_default = true
        },
        {
            name = "Verbosity",
            type = "option",
            default = "default",
            options = {
                "quiet",
                "default",
                "verbose",
                "extra verbose",
                "debug",
                "debug-verbose",
                "debug-extra verbose",
            },
            omit_default = true,
            custom_cmd = function(value)
                if value == "quiet" then
                    return "--quiet"
                elseif value == "verbose" then
                    return "--verbose"
                elseif value == "extra verbose" then
                    return "--extra-verbose"
                elseif value == "debug" then
                    return "--debug"
                elseif value == "debug-verbose" then
                    return "--debug --verbose"
                elseif value == "debug-extra verbose" then
                    return "--debug --extra-verbose"
                else
                    return ""
                end
            end
        },
        {
            name = "Output on Fail",
            type = "boolean",
            default = true,
            arg_prefix = "--output-on-failure",
            bool_display = true,
        },
        {
            name = "Stop on Fail",
            type = "boolean",
            default = false,
            arg_prefix = "--stop-on-failure",
            bool_display = true
        },
        {
            name = "Failover",
            type = "boolean",
            default = false,
            arg_prefix = "-F",
            bool_display = true
        },
        {
            name = "Output File",
            type = "string",
            default = "",
            arg_prefix = "-O "
        },
        {
            name = "JUnit Output File",
            type = "string",
            default = "",
            arg_prefix = "--output-junit "
        },
        {
            name = "Repeat",
            type = "string",
            default = "",
            validate = function(value)
                if value == "" then return true end
                local num_idx
                if string.sub(value, 1, 11) == "until-fail:" then
                    num_idx = 12
                elseif string.sub(value, 1, 11) == "until-pass:" then
                    num_idx = 12
                elseif string.sub(value, 1, 14) == "after-timeout:" then
                    num_idx = 15
                else
                    print(
                        "Should be in form [mode]:[number]"
                        .."\n where [mode] is one of: until-fail, until-pass, or until-timeout"
                        .."\n and where [number] is a positive integer."
                    )
                    return false
                end

                local num = tonumber(string.sub(value, num_idx))
                if num == nil then
                    print(
                        "Should be in form [mode]:[number]"
                        .."\n where [mode] is one of: until-fail, until-pass, or until-timeout"
                        .."\n and where [number] is a positive integer"
                    )
                    return false
                end
                return true
            end,
            omit_default = true,
            arg_prefix = "--"
        },
        {
            name = "Timeout",
            type = "number",
            default = -1,
            validate = function(num)
                local out = math.floor(num) == num and num >= 0
                if out == false then
                    print("Value must be a non-negative integer. 0 signifies no timeout is specified.")
                end
                return out
            end,
            arg_prefix = "--timeout ",
            omit_default = true
        },
        {
            name = "Other Args",
            type = "list",
            default = {}
        }
    }
}

---@type ActionGroup
return {
    name = "CMake",
    actions = {
        {
            desc = "Initialize",
            configs = { "initialize" },
            callback = function (configs)
                vim.fn.delete(vim.fn.getcwd().."/build", "rf")
                utils.runInTerminal(utils.generateCommand(
                    "cmake",
                    configs.initialize,
                    config_types.initialize
                ))
            end
        },
        {
            bind = "cc",
            desc = "Compile",
            configs = { "compile" },
            callback = function (configs)
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal(utils.generateCommand(
                    "cmake --build build",
                    configs.compile,
                    config_types.compile
                ))
            end
        },
        {
            bind = "r",
            desc = "Run",
            configs = { "run" },
            callback = function (configs)
                utils.runInTerminal(utils.generateCommand(
                    "",
                    configs.run,
                    config_types.run
                ):sub(2))
            end
        },
        {
            bind = "cr",
            desc = "Compile and Run",
            configs = { "run", "compile" },
            callback = function (configs)
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal(
                    utils.generateCommand(
                        "cmake --build build",
                        configs.compile,
                        config_types.compile
                    )
                    .. " && " ..
                    utils.generateCommand(
                        "",
                        configs.run,
                        config_types.run
                    ):sub(2)
                )
            end
        },
        {
            bind = "t",
            desc = "Test",
            configs = { "test" },
            callback = function (configs)
                utils.runInTerminal(utils.generateCommand(
                    "ctest --test-dir build",
                    configs.test,
                    config_types.test
                ))
            end
        },
        {
            bind = "ct",
            desc = "Compile and Test",
            configs = { "compile", "test" },
            callback = function (configs)
                utils.mkdir(vim.fn.getcwd().."/build")
                utils.runInTerminal(
                    utils.generateCommand(
                        "cmake --build build",
                        configs.compile,
                        config_types.compile
                    )
                    .. " && " ..
                    utils.generateCommand(
                        "ctest --test-dir build",
                        configs.test,
                        config_types.test
                    )
                )
            end
        },
        {
            desc = "Load Presets",
            callback = function ()
                local presets_path = vim.fn.getcwd().."/CMakeUserPresets.json"

                if vim.uv.fs_stat(presets_path) ~= nil then
                    print("A file already exists at '"..presets_path.."'. Please remove it first.")
                    return
                end

                local presets_file = io.open(presets_path, "w")
                if presets_file ~= nil then
                    presets_file:write(basic_user_presets)
                    presets_file:close()
                else
                    error("Unable to write to file: '"..presets_path.."'.")
                end
            end
        }
    },
    detect = function()
        return vim.fn.filereadable(vim.fn.getcwd().."/CMakeLists.txt") == 1
    end,
    config_types = config_types
}
