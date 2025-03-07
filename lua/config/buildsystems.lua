local M = {}

local popup = require("plenary.popup")

--------------------------------------------------------------------
--Utility Functions
--------------------------------------------------------------------

-- Trim whitespace from both ends of a string
local function trim(s)
    local l = 1
    while string.sub(s, l, l) == ' ' do
        l = l+1
    end

    local r = string.len(s)
    while string.sub(s, r, r) == ' ' do
        r = r-1
    end

    return string.sub(s, l, r)
end

-- Check if a file or directory exists in this path
local function isDirectoryEntry(path)
    return vim.uv.fs_stat(path) ~= nil
end

-- Check if the path is a valid directory
local function isDirectory(path)
    local entry = vim.uv.fs_stat(path)
    return entry ~= nil and entry.type == "directory"
end

-- Run a command in the terminal emulator
local function runInTerminal(args)
    vim.cmd("tabnew")
    vim.cmd("terminal " .. args)
    vim.cmd("startinsert")
end

--------------------------------------------------------------------
--BuildSystem data
--------------------------------------------------------------------

local bs = {}

bs["cmake"] = {
    detect = function ()
        return isDirectoryEntry(vim.fn.getcwd().. "/CMakeLists.txt")
    end,
    commands = {
        c = {
            desc = "Compile",
            callback = function ()
                runInTerminal("cmake --build build")
            end
        },
        b = {
            desc = "Build",
            callback = function ()
                runInTerminal("rmdir build /s /q && cmake --preset=debug -B build -S .")
            end
        },
        r = {
            desc = "Run",
            callback = function ()
                runInTerminal("/build/main.exe")
            end
        },
        m = {
            desc = "Compile and Run",
            callback = function ()
                runInTerminal("cmake --build build && /build/main.exe")
            end
        },
    },
}

bs["cargo"] = {
    detect = function ()
        return isDirectoryEntry(vim.fn.getcwd().. "/Cargo.toml")
    end,
    commands = {
        c = {
            desc = "Compile",
            callback = function ()
                runInTerminal("cargo build")
            end
        },
        r = {
            desc = "Run",
            callback = function ()
                runInTerminal("cargo run")
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
    --if M.menuId ~= nil then
        pcall(vim.api.nvim_win_close, M.menuId, true)
    --end
    M.menuId = nil
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
        M.menuId = nil
        return
    end

    local commandList = current.commands or nil
    if commandList == nil then
        print("There are no commands for the current buildsystem.")
        M.menuId = nil
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

    local width = 30
    local borderchars = {"─", "│", "─", "│", "┌", "┐", "┘", "└", }

    local winId = popup.create(
        menuText,
        {
            title = "BuildSystem Commands",
            highlight = "kanagawa",
            line = math.floor(((vim.o.lines - height) / 2) - 1),
            col = math.floor((vim.o.columns - width) / 2),
            minwidth = width,
            minheight = height,
            borderchars = borderchars,
            callback = M.handleMenuInput,
        }
    )
    local bufnr = vim.api.nvim_win_get_buf(winId)

    M.menuId = winId

    vim.api.nvim_set_option_value(
        "modifiable",
        false,
        {
            buf = bufnr
        }
    )

    for keybind, _ in pairs(commandList) do
        vim.api.nvim_buf_set_keymap(
            bufnr,
            "n",
            keybind,
            "<cmd>lua require(\"config.buildsystems\").runCommand(\"" .. keybind .. "\")<CR>",
            {silent = true}
        )
    end

    vim.api.nvim_buf_set_keymap(
        bufnr,
        "n",
        "q",
        "<cmd>lua require(\"config.buildsystems\").closeMenu()<CR>",
        {silent = true}
    )

    vim.api.nvim_create_autocmd(
        "QuitPre",
        {
            buffer = bufnr,
            callback = function ()
                -- window cannot be destroyed if cursor is on it
                if vim.fn.win_getid() ~= winId then
                    M.closeMenu()
                end
            end,
        }
    )

end

--open the project menu
function M.projectMenu()
    --only one buildsystems menu should be active at a time
    M.closeMenu()

    --read environment variable for project folder
    local projFoldersRaw = os.getenv("ProjectLocations")
    if projFoldersRaw == nil then
        print("'ProjectLocations' environment variable has not been set.\nThis is necessary to locate projects.")
        return
    end

    --collect all project folders into a table (should be a ; separated list w/o quotes)
    local projects = {}
    local projectCount = 0
    for path in (projFoldersRaw .. ";"):gmatch("([^;]*);") do
        local tpath = trim(path)

        if isDirectory(tpath) then
            local iter = vim.uv.fs_scandir(tpath)
            local name, type = vim.uv.fs_scandir_next(iter)
            while name ~= nil do
                if type == "directory" then
                    local project = {}
                    projectCount = projectCount + 1
                    project.name = name
                    project.path = tpath .. "/" .. name
                    table.insert(projects, project)
                end
                name, type = vim.uv.fs_scandir_next(iter)
            end
        else
            print(tpath .. " is not a valid projects folder")
        end
    end

    if projectCount == 0 then
        print("No projects found.")
        return
    end

    --generate menu text
    local maxDigits = math.floor(math.log10(projectCount))
    local menuText = {}
    local height = 0
    local index = 1
    for _, project in pairs(projects) do
        local indexDigits = math.floor(math.log10(projectCount))
        local padding = string.rep(" ", maxDigits - indexDigits)
        table.insert(menuText, padding .. index .. " - " .. project.name)
        project.index = index
        height = height + 1
        index = index + 1
    end

    local width = 30
    local borderchars = {"─", "│", "─", "│", "┌", "┐", "┘", "└", }

    local winId = popup.create(
        menuText,
        {
            title = "Projects",
            highlight = "kanagawa",
            line = math.floor(((vim.o.lines - height) / 2) - 1),
            col = math.floor((vim.o.columns - width) / 2),
            minwidth = width,
            minheight = height,
            borderchars = borderchars,
            callback = M.handleMenuInput,
        }
    )
    local bufnr = vim.api.nvim_win_get_buf(winId)

    M.menuId = winId

    vim.api.nvim_set_option_value(
        "modifiable",
        false,
        {
            buf = bufnr
        }
    )

    for _, project in pairs(projects) do
        vim.api.nvim_buf_set_keymap(
            bufnr,
            "n",
            tostring(project.index) .. "<CR>",
            "<cmd>lua require(\"config.buildsystems\").closeMenu()<CR>"
            .."<cmd>cd "..project.path.."<CR>"
            .."<cmd>e "..project.path.."<CR>",
            {silent = true}
        )
    end

    vim.api.nvim_buf_set_keymap(
        bufnr,
        "n",
        "q",
        "<cmd>lua require(\"config.buildsystems\").closeMenu()<CR>",
        {silent = true}
    )

    vim.api.nvim_create_autocmd(
        "QuitPre",
        {
            buffer = bufnr,
            callback = function ()
                -- window cannot be destroyed if cursor is on it
                if vim.fn.win_getid() ~= winId then
                    M.closeMenu()
                end
            end,
        }
    )

end

function M.init()
    if next(vim.fn.argv()) == nil then
        M.projectMenu()
    end

    M.refreshBuildSystem()
end

local acgroup = vim.api.nvim_create_augroup("BuildSystem", {clear = true})
vim.api.nvim_create_autocmd(
    'DirChanged',
    {
        pattern = 'global',
        group = acgroup,
        callback = M.refreshBuildSystem,
    }
)
vim.api.nvim_create_autocmd(
    'VimEnter',
    {
        group = acgroup,
        callback =  M.init,
    }
)

vim.api.nvim_create_user_command(
    "Proj",
    M.projectMenu,
    {
        nargs = 0,
        desc = "Opens the project picker",
    }
)

return M
