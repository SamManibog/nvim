local M = {}

local popup = require("config.popup")
local utils = require("config.utils")

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
        local tpath = utils.trim(path)

        if utils.isDirectory(tpath) then
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
    local index = 1
    local index_map = {}
    for _, project in pairs(projects) do
        local indexDigits = math.floor(math.log10(projectCount))
        local padding = string.rep(" ", maxDigits - indexDigits)
        table.insert(menuText, padding .. index .. " - " .. project.name)
        index_map[index] = project.path
        index = index + 1
    end
    table.insert(menuText, string.rep(" ", maxDigits - 1).."n - [new project]")
    table.insert(menuText, string.rep(" ", maxDigits - 1).."q - [exit]")

    local p = popup.new_input({
        text = menuText,
        title = "Projects",
        width = 30,
        border = true,
        prompt = "> ",
        verify_input = function (text)
            if
                text == "n"
                or text == "q"
            then
                return true
            end
            local p_index = tonumber(text)
            if
                p_index == nil
                or p_index ~= math.floor(p_index)
            then
                return false
            else
                return p_index >= 1 and p_index < index
            end
        end,
        on_confirm = function (text)
            if text == "n" then
                print("todo")
            elseif text == "q" or text == "0" then
                M.closeMenu()
            else
                local p_path = index_map[tonumber(text)]
                M.closeMenu()
                vim.cmd("cd "..p_path)
                vim.cmd("e "..p_path)
            end
        end
    })

    M.popup = p
end

function M.closeMenu()
    if M.popup ~= nil then
        M.popup:close()
    end
    M.popup = nil
end

vim.api.nvim_create_user_command(
    "Proj",
    M.projectMenu,
    {
        nargs = 0,
        desc = "Opens the project picker",
    }
)

vim.api.nvim_create_autocmd(
    'VimEnter',
    {
        callback = function ()
            if next(vim.fn.argv()) == nil then
                --M.projectMenu()
                vim.schedule(M.projectMenu)
            end
        end
    }
)

return M
