local M = {}

local PromptPopup = require("oneup.prompt_popup")

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
            local tpath = trim(path)

            if vim.fn.isdirectory(tpath) == 1 then
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
            local tpath = trim(path)

            if vim.fn.isdirectory(tpath) == 1 then
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

    local p
    p = PromptPopup:new({
        text = menuText,
        title = "Projects",
        width = { value = "20%", min = 20 },
        border = true,
        prompt = "> ",
        verify_input = function (text)
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
    }, true)

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
