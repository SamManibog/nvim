local M = {}

local popup = require("config.popup")
local utils = require("config.utils")

--------------------------------------------------------------------
--BuildSystem data
--------------------------------------------------------------------

local bs = {}

bs["cmake"] = {
    detect = function ()
        return utils.isDirectoryEntry(vim.fn.getcwd().. "/CMakeLists.txt")
    end,
    commands = {
        c = {
            desc = "Compile",
            callback = function ()
                utils.runInTerminal("cmake --build build")
            end
        },
        b = {
            desc = "Build",
            callback = function ()
                utils.runInTerminal("rmdir build /s /q && cmake --preset=debug -B build -S .")
            end
        },
        r = {
            desc = "Run",
            callback = function ()
                utils.runInTerminal("/build/main.exe")
            end
        },
        m = {
            desc = "Compile and Run",
            callback = function ()
                utils.runInTerminal("cmake --build build && /build/main.exe")
            end
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
    M.currentBuildSystem = nil
    --detect current buildsystem
    for _, data in pairs(M.buildSystems) do
        if data.detect ~= nil and data.detect() then
            M.currentBuildSystem = data
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

function M.closeMenu()
    if M.popup ~= nil then
        M.popup:close()
    end
    M.popup = nil
end

function M.runCommand(keybind)
    local cmdList = M.currentBuildSystem.commands or nil
    if cmdList ~= nil and cmdList[keybind] ~= nil then
        cmdList[keybind].callback()
    end
    M.closeMenu()
end

function M.taskMenu()
    --only one buildsystems menu should be active at a time
    M.closeMenu()

    local current = M.currentBuildSystem
    if current == nil then
        print("There are no commands for the current buildsystem.")
        M.popup = nil
        return
    end

    local commandList = current.commands or nil
    if commandList == nil then
        print("There are no commands for the current buildsystem.")
        M.popup = nil
        return
    end

    local menuText = {}

    local height = 0
    for keybind, command in pairs(commandList) do
        table.insert(menuText, keybind .. " - " .. command.desc)
        height = height + 1
    end

    if height == 0 then
        print("There are no commands for the current buildsystem.")
        return
    end

    local p = popup.new({
        text = menuText,
        title = "Projects",
        width = 30,
        border = true,
    })

    for keybind, _ in pairs(commandList) do
        vim.api.nvim_buf_set_keymap(
            p:get_buf_id(),
            "n",
            keybind,
            "<cmd>lua require(\"config.buildsystems\").runCommand(\"" .. keybind .. "\")<CR>",
            {silent = true}
        )
    end

    vim.api.nvim_buf_set_keymap(
        p:get_buf_id(),
        "n",
        "q",
        "<cmd>lua require(\"config.buildsystems\").closeMenu()<CR>",
        {silent = true}
    )

    M.popup = p
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
