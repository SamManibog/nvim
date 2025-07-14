local utils = require("director.utils")

---@class CMakeOpts
---@field build_folder_name string? the name of folder in which to place compiled binaries
---@field user_presets table? a table used to write a basic user presets file, if non-nil, creates an unbound action to write this file to the current working directory
---@field init_preset string? the default preset name used for cmake builds, leave nil for no preset
---@field compile_preset string? the default preset name used for cmake compilation, leave nil for no preset
---@field executable_search_depth integer? the maximum depth to search for run config options
---@field binds CMakeBindsOpts?

---@class CMakeBindsOpts
---@field compile string?
---@field compile_run string?
---@field compile_test string?
---@field run string?
---@field test string?
---@field init string?

---@cllass CMakeBindsOpts
local bind_defaults = {
    compile = "cc",
    compile_run = "cr",
    compile_test = "ct",
    run = "r",
    test = "t",
    init = "i"
}

---@class CMakeOpts
local defaults = {
    build_folder_name = "build",
    user_presets = nil,
    init_preset = "",
    compile_preset = "",
    executable_search_depth = 6,
}

---returns a terminal command for compilation given the specified opts
---@param path string
---@param opts table
---@return string
local function generateCompileCommand(path, opts)
    local cmd = "cmake --build "..path
    if #opts.Preset > 0 then
        cmd = cmd.." --preset="..opts.Preset
    end
    if #opts.Targets > 0 then
        cmd = cmd.." -t"
        for _, target in pairs(opts.Targets) do
            cmd = cmd.." "..target
        end
    end
    if opts["Clean First"] then
        cmd = cmd.." --clean-first"
    end
    if opts.Verbose then
        cmd = cmd.." -v"
    end
    if opts["Resolve References"] ~= "on" then
        cmd = cmd.." --resolve-package-references"..opts["Resolve References"]
    end
    if opts["Parallel Jobs"] ~= 0 then
        cmd = cmd.." -j "..tostring(opts["Parallel Jobs"])
    end
    if #opts["Build Tool Args"] > 0 then
        cmd = cmd.." --"
        for _, arg in pairs(opts["Build Tool Args"]) do
            cmd = cmd.." "..arg
        end
    end
    return cmd
end

---returns a terminal command for cmake initialization given the specified opts
---@param path string
---@param opts table
---@return string
local function generateInitCommand(path, opts)
    local cmd = "cmake -B"..path
    if #opts.Preset > 0 then
        cmd = cmd.." --preset="..opts.Preset
    end
    if #opts.Generator > 0 then
        cmd = cmd.." -G "..opts.Generator
    end
    if #opts["Toolset Spec"] > 0 then
        cmd = cmd.." -T "..opts["Toolset Spec"]
    end
    if #opts["Platform Name"] > 0 then
        cmd = cmd.." -A "..opts["Platform Name"]
    end
    if #opts["Toolchain"] > 0 then
        cmd = cmd.." --toolchain "..opts["Toolchain"]
    end
    if #opts["Install Prefix"] > 0 then
        cmd = cmd.." --install-prefix "..opts["Install Prefix"]
    end
    if opts["Log Level"] ~= "STATUS" then
        cmd = cmd.." --log-level"..opts["Log Level"]
    end
    if #opts["Other Args"] > 0 then
        for _, arg in pairs(opts["Other Args"]) do
            cmd = cmd.." "..arg
        end
    end
    return cmd
end

---returns a terminal command for running an executable built by cmake
---@param path string
---@param opts table
---@return string
local function generateRunCommand(path, opts)
    local cmd = "\"./"..path.."/"..opts.Target.."\""
    for _, arg in pairs(opts.Arguments) do
        cmd = cmd.." "..arg
    end
    return cmd
end

---@type fun(opts: CMakeOpts): ActionGroup
return function(opts)
    opts = opts or {}
    local opts_binds = opts.binds or {}

    ---@type CMakeOpts
    local config = vim.tbl_extend("force",
        defaults,
        opts
    )
    config.binds = vim.tbl_extend("force",
        bind_defaults,
        opts_binds
    )

    ---lists all built executables relative to the build folder
    ---@return string[]
    local function listBuiltExes()
        return utils.listFiles(
            vim.fn.getcwd().."/"..config.build_folder_name,
            function (path)
                return vim.fn.executable(path) == 1
            end,
            function (path)
                local name = vim.fn.fnamemodify(path, ":t")
                return name ~= "CMakeFiles" and name ~= ".cmake" and name ~= "Testing"
            end,
            config.executable_search_depth
        )
    end

    ---@type ActionDescriptor[]
    local actions = {
        {
            bind = config.binds.init,
            desc = "Initialize",
            configs = { "initialize" },
            callback = function (configs)
                utils.rmrf(vim.fn.getcwd().."/"..config.build_folder_name)
                utils.runInTerminal(
                    generateInitCommand(
                        config.build_folder_name,
                        configs.initialize
                    )
                )
            end
        },
        {
            bind = config.binds.compile,
            desc = "Compile",
            configs = { "compile" },
            callback = function (configs)
                utils.mkdir(vim.fn.getcwd().."/"..config.build_folder_name)
                utils.runInTerminal(
                    generateCompileCommand(
                        config.build_folder_name,
                        configs.compile
                    )
                )
            end
        },
        {
            bind = config.binds.run,
            desc = "Run",
            configs = { "run" },
            callback = function (configs)
                utils.runInTerminal(
                    generateRunCommand(
                        config.build_folder_name,
                        configs.run
                    )
                )
            end
        },
        {
            bind = config.binds.compile_run,
            desc = "Compile and Run",
            configs = { "run", "compile" },
            callback = function (configs)
                utils.mkdir(vim.fn.getcwd().."/"..config.build_folder_name)
                utils.runInTerminal(
                    generateCompileCommand(
                        config.build_folder_name,
                        configs.compile
                    )
                    .. " && " ..
                    generateRunCommand(
                        config.build_folder_name,
                        configs.run
                    )
                )
            end
        },
        {
            bind = config.binds.test,
            desc = "Test",
            callback = function ()
                utils.runInTerminal("cd "..config.build_folder_name.." && ctest")
            end
        },
        {
            bind = config.binds.compile_test,
            desc = "Compile and Test",
            callback = function ()
                error("todo")
                utils.mkdir(vim.fn.getcwd().."/"..config.build_folder_name)
                --utils.runInTerminal("cmake --build build && cd build && ctest")
            end
        },
    }

    if config.user_presets ~= nil then
        table.insert(actions, {
            desc = "Load Presets",
            callback = function ()
                local presets_path = vim.fn.getcwd().."/CMakeUserPresets.json"

                if vim.uv.fs_stat(presets_path) ~= nil then
                    print("A file already exists at '"..presets_path.."'. Please remove it first.")
                    return
                end

                local presets_file = io.open(presets_path, "w")
                if presets_file ~= nil then
                    presets_file:write(vim.fn.json_encode(config.user_presets))
                    presets_file:close()
                else
                    error("Unable to write to file: '"..presets_path.."'.")
                end
            end
        })
    end

    ---@type ActionGroup
    return {
        name = "CMake",
        detect = function()
            return vim.fn.filereadable(vim.fn.getcwd().."/CMakeLists.txt") == 1
        end,
        config_types = {
            initialize = {
                {
                    name = "Preset",
                    type = "string",
                    default = config.init_preset
                },
                {
                    name = "Generator",
                    type = "string",
                    default = "",
                },
                {
                    name = "Toolset Spec",
                    type = "string",
                    default = "",
                },
                {
                    name = "Platform Name",
                    type = "string",
                    default = "",
                },
                {
                    name = "Toolchain",
                    type = "string",
                    default = "",
                },
                {
                    name = "Install Prefix",
                    type = "string",
                    default = "",
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
                    }
                },
                {
                    name = "Other Args",
                    type = "list",
                    default = {}
                }
            },
            compile = {
                {
                    name = "Preset",
                    type = "string",
                    default = config.compile_preset
                },
                {
                    name = "Targets",
                    type = "list",
                    default = {}
                },
                {
                    name = "Clean First",
                    type = "boolean",
                    default = false,
                },
                {
                    name = "Verbose",
                    type = "boolean",
                    default = false,
                },
                {
                    name = "Resolve References",
                    type = "option",
                    default = "on",
                    options = { "on", "only", "off" }
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
                    end
                },
                {
                    name = "Build Tool Args",
                    type = "list",
                    default = {},
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
                    end
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
                    default = ""
                },
                {
                    name = "Progress Messages",
                    type = "boolean",
                    default = false
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
                    end
                },
                {
                    name = "Test Load",
                    type = "number",
                    default = 0,
                    validate = function(num)
                        local out = math.floor(num) == num and num >= 0
                        if out == false then
                            print("Value must be a non-negative integer.")
                        end
                        return out
                    end
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
                    }
                },
                {
                    name = "Output on Fail",
                    type = "boolean",
                    default = true
                },
                {
                    name = "Stop on Fail",
                    type = "boolean",
                    default = false
                },
                {
                    name = "Failover",
                    type = "boolean",
                    default = false
                },
                {
                    name = "Output File",
                    type = "string",
                    default = ""
                },
                {
                    name = "JUnit Output File",
                    type = "string",
                    default = ""
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
                    end
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
                    end
                },
                {
                    name = "Other Args",
                    type = "list",
                    default = {}
                }
            }
        },
        actions = actions
    }
end
