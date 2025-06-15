local M = {}

local popup = require("config.popup")
local utils = require("config.utils")

--------------------------------------------------------------------
--BuildSystem data
--------------------------------------------------------------------

local bs = {}

bs["cmake"] = {
    detect = function ()
        return utils.isDirectoryEntry(vim.fn.getcwd().."/CMakeLists.txt")
    end,
    commands = {
        cc = {
            desc = "Compile",
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build")
            end
        },
        b = {
            desc = "Build",
            callback = function ()
                if utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_rmdir(vim.fn.getcwd().."/build")
                end
                utils.runInTerminal("cmake --preset=debug -B build -S .")
            end
        },
        r = {
            desc = "Run",
            callback = function ()
                utils.runInTerminal("\"./build/main.exe\"")
            end
        },
        cr = {
            desc = "Compile and Run",
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && \"./build/main.exe\"")
            end
        },
        ts = {
            desc = "Test (Silent)",
            callback = function ()
                utils.runInTerminal("cd build && ctest")
            end
        },
        tl = {
            desc = "Test (Verbose)",
            callback = function ()
                utils.runInTerminal("cd build && ctest --verbose")
            end
        },
        cts = {
            desc = "Compile and Test (Silent)",
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && cd build && ctest")
            end
        },
        ctl = {
            desc = "Compile and Test (Verbose)",
            callback = function ()
                if not utils.isDirectory(vim.fn.getcwd().."/build") then
                    vim.uv.fs_mkdir(vim.fn.getcwd().."/build", tonumber("777", 8))
                end
                utils.runInTerminal("cmake --build build && cd build && ctest --verbose")
            end
        },
        I = {
            desc = "Install as Package",
            callback = function ()
                local package_folder = os.getenv("CMakePackagePath")
                if package_folder == nil then
                    print("CMakePackagePath environment variable must be set")
                end
                if utils.isDirectoryEntry(package_folder) then
                    if utils.isDirectory(vim.fn.getcwd().."/build") then
                        vim.uv.fs_rmdir(vim.fn.getcwd().."/build")
                    end
                    utils.runInTerminal([[cmake -G "MinGW Makefiles" -B build -S . -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DCMAKE_EXPORT_COMPILE_COMMANDS=1 --install-prefix "C:\Users\sfman\Packages\Installed" && cmake --build build && cmake --install build --config Debug]])
                else
                    print(package_folder.." is not a valid directory")
                end
            end,
        },
    },
}

bs["cargo"] = {
    detect = function ()
        return utils.isDirectoryEntry(vim.fn.getcwd().. "/Cargo.toml")
    end,
    commands = {
        c = {
            desc = "Compile",
            callback = function ()
                utils.runInTerminal("cargo build")
            end
        },
        r = {
            desc = "Run",
            callback = function ()
                utils.runInTerminal("cargo run")
            end
        },
    }
}

for key, _ in pairs(bs) do
    bs[key]["name"] = key
end

M.buildSystems = bs

--------------------------------------------------------------------
--Module Functions
--------------------------------------------------------------------

--refreshes the global projectBuildSystem variable
function M.refreshBuildSystem()
    if
        M.currentBuildSystem ~= nil
        and M.currentBuildSystem.on_detatch ~= nil
    then
        M.currentBuildSystem.on_detatch()
    end
    M.currentBuildSystem = nil
    --detect current buildsystem
    for _, data in pairs(M.buildSystems) do
        if data.detect ~= nil and data.detect() then
            M.currentBuildSystem = data
            if data.on_attatch ~= nil then
                data.on_attatch()
            end
            break
        end
    end
end

function M.recognizedBuildSystems()
    local list = {}
    local index = 0
    for _, data in pairs(M.buildSystems) do
        list[index] = data.name
        index = index + 1
    end
    return list
end

--[[
function M.closeMenu()
    if M.popup ~= nil then
        M.popup:close()
    end
    M.popup = nil
end
]]

function M.taskMenu()
    local current = M.currentBuildSystem
    if current == nil then
        print("There are no commands for the current buildsystem.")
        return
    end

    local commandList = current.commands or nil
    if commandList == nil then
        print("There are no commands for the current buildsystem.")
        return
    end

    local tasks = {}
    for bind, command in pairs(commandList) do
        table.insert(tasks, {
            bind = bind,
            desc = command.desc,
            callback = command.callback
        })
    end

    popup.new_actions_menu(
        tasks,
        {
            title = "Tasks",
            text = {},
            width = 30,
            border = true,
            closeBinds = { "<C-c>", "q" }
        }
    )
end

vim.api.nvim_create_autocmd(
    'DirChanged',
    {
        pattern = 'global',
        callback = M.refreshBuildSystem,
    }
)

vim.api.nvim_create_autocmd(
    'VimEnter',
    {
        callback =  M.refreshBuildSystem,
    }
)

return M
