local M = {}

local popup = require("config.popup")
local utils = require("config.utils")

--[===[
--todo
--add ability to create new project/new project menu
    --add projects folder picker to specify which folder to use
    --add template picker to chose a template
    --add menu to enter opts, using either popup.new_input or popup.new_adv_input

-----------------------------------------------------------------------------------
---Frontend
-----------------------------------------------------------------------------------
---@type {[string]: {
---     opts: {[string]: (fun(text:string):boolean)?},
---     template: fun(table):DirEntry}}
M.templates = {
    cmake = {--the name of the template
        opts = {--a table of options that the user will be prompted to fill out
            --prompt = verify_input_callback (or nil)
        },
        --spec = dirspec_generator_callback
    }
}

-----------------------------------------------------------------------------------
---Backend
-----------------------------------------------------------------------------------

---@class DirEntry a representation of some sub directory
---@field name string the name of the file including possible extensions (but not the path)
---@field text (string | fun(opts: table):string)? text contents (files only)
---@field entries (DirEntry[] | fun(opts: table):DirEntry[])? entry contents (folders only)

---creates the given directory an all of its contents as a child of the given path
---@param dir_entry DirEntry the directory entry to use as a template
---@param path string the path at which to create the directory
---@param opts table? a table of options to be called by contents functions
function M.load_template(dir_entry, path, opts)
    if dir_entry.name == nil then
        print("invalid template, entries must have name field")
    end
    if
        (dir_entry.text == nil and dir_entry.entries == nil)
        or (dir_entry.text ~= nil and dir_entry.entries ~= nil)
    then
        print("invalid template, entries must have EITHER a text OR entries field")
    end

    if opts == nil then
        opts = {}
    end
    if utils.isDirectory(path) then
        if type(dir_entry.entries) ~= "nil" then
            ---@type DirEntry[]
            local entries
            if type(dir_entry.entries) == "function" then
                entries = dir_entry.entries(opts)
            else
                entries = dir_entry.entries --[[@as DirEntry[] ]]
            end

            local dir_name = path.."/"..dir_entry.name

            if utils.isDirectoryEntry(dir_name) then
                error("file "..dir_name.." already exists")
            end

            vim.uv.fs_mkdir(dir_name, tonumber("777", 8))

            ---@type _, DirEntry
            for _, entry in pairs(entries) do
                M.load_template(entry, dir_name, opts)
            end
        else
            ---@type string
            local text
            if type(dir_entry.text) == "function" then
                text = dir_entry.text(opts)
            else
                text = dir_entry.text --[[@as string]]
            end

            local file_name = path.."/"..dir_entry.name

            if utils.isDirectoryEntry(file_name) then
                error("file "..file_name.." already exists")
            end

            local file = io.open(file_name, "w")
            if file ~= nil then
                file:write(text)
                file:close()
            else
                error("unable to create file "..file_name)
            end
        end
    else
        error(path.." is not a valid directory")
    end
end

function M.new_project()
end
]===]

--open the project menu
function M.project_menu()
    --read environment variable for project folder
    local projFolderGroupsRaw = os.getenv("PRO_PICKER_DIR_LOCATIONS")
    local projFoldersRaw = os.getenv("PRO_PICKER_LOCATIONS")
    if projFoldersRaw == nil and projFolderGroupsRaw == nil then
        print(
            "'PRO_PICKER_DIR_LOCATIONS' and 'PRO_PICKER_LOCATIONS' environment variables have not been set."
            .."\nThese are necessary to locate projects."
            .."\n'PRO_PICKER_DIR_LOCATIONS' stores a semicolon delimited list of folders that contain many projects."
            .."\n'PRO_PICKER_LOCATIONS' stores a semicolon delimited list individual project folders."
        )
        return
    end

    --collect all project folders into a table (should be a ; separated list w/o quotes)
    local projects = {}
    local projectCount = 0

    --handle groups
    if projFolderGroupsRaw ~= nil then
        for path in (projFolderGroupsRaw .. ";"):gmatch("([^;]*);") do
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
            elseif tpath ~= "" then
                print(tpath .. " is not a valid project groups folder")
            end
        end
    end

    --handle individual projects
    if projFoldersRaw ~= nil then
        for path in (projFoldersRaw .. ";"):gmatch("([^;]*);") do
            local tpath = utils.trim(path)

            if utils.isDirectory(tpath) then
                local project = {}
                projectCount = projectCount + 1
                project.name = vim.fn.fnamemodify(path, ":t")
                project.path = tpath
                table.insert(projects, project)
            elseif tpath ~= "" then
                print(tpath .. " is not a valid project folder")
            end
        end
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
    --table.insert(menuText, string.rep(" ", maxDigits - 1).."n - [new project]")
    table.insert(menuText, string.rep(" ", maxDigits - 1).."q - [exit]")

    local p
    p = popup.new_input({
        text = menuText,
        title = "Projects",
        width = 30,
        border = true,
        prompt = "> ",
        verify_input = function (text)
            if
                text == "q"
                --or text == "n"
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
            if text == "q" or text == "0" then
                p:close()
            --elseif text == "n" then
                --print("todo")
            else
                local p_path = index_map[tonumber(text)]
                p:close()
                vim.cmd("cd "..p_path)
                vim.cmd("e "..p_path)
                --ModeChanged is not emitted properly without this
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(
                        ":<BS>",
                            true,
                            false,
                            true
                    ),
                    'n',
                    false
                )
            end
        end
    })

    M.popup = p
end

vim.api.nvim_create_user_command(
    "Proj",
    M.project_menu,
    {
        nargs = 0,
        desc = "Opens the project picker",
    }
)

vim.api.nvim_create_autocmd(
    'UIEnter',
    {
        callback = function ()
            if next(vim.fn.argv()) == nil then
                M.project_menu()
            end
        end,
        once = true
    }
)

return M
