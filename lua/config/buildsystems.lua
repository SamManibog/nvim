local M = {}

--------------------------------------------------------------------
--Utility Functions
--------------------------------------------------------------------

--- Check if a file or directory exists in this path
local function isDirectoryEntry(path)
   local ok, err, code = os.rename(path, path)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

--- Run a command in the terminal emulator
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
    load = function ()
        vim.api.nvim_create_user_command(
            "Make",
            function ()
                runInTerminal("cmake --build build")
            end,
            {
                nargs = 0,
                desc = "Compile the project"
            }
        )
        vim.api.nvim_create_user_command(
            "Build",
            function ()
                runInTerminal("rmdir build /s /q && cmake --preset=debug -B build -S .")
            end,
            {
                nargs = 0,
                desc = "Rebuild the entire project and cmake cache"
            }
        )
        vim.api.nvim_create_user_command(
            "Run",
            function ()
                runInTerminal("/build/main.exe")
            end,
            {
                nargs = 0,
                desc = "Run the project"
            }
        )
        vim.api.nvim_create_user_command(
            "Mar",
            function ()
                runInTerminal("cmake --build build && /build/main.exe")
            end,
            {
                nargs = 0,
                desc = "Compile and run the project"
            }
        )
    end,
    unload = function ()
        for _, name in pairs({"Make", "Build", "Run"}) do
            vim.api.nvim_del_user_command(name)
        end
    end
}

bs["cargo"] = {
    detect = function ()
        return isDirectoryEntry(vim.fn.getcwd().. "/Cargo.toml")
    end,
    load = function ()
        vim.api.nvim_create_user_command(
            "Make",
            function ()
                runInTerminal("cargo build")
            end,
            {
                nargs = 0,
                desc = "Compile the project"
            }
        )
        vim.api.nvim_create_user_command(
            "Run",
            function ()
                runInTerminal("cargo run")
            end,
            {
                nargs = 0,
                desc = "Compile and run the project"
            }
        )
    end,
    unload = function ()
        for _, name in pairs({"Make", "Build", "Run"}) do
            vim.api.nvim_del_user_command(name)
        end
    end
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
    --unload current buildsystem
    if
        vim.g.projectBuildSystem ~= nil
        and vim.g.projectBuildSystem.unload ~= nil
    then
        vim.g.projectBuildSystem.unload()
    end

    vim.g.projectBuildSystem = nil

    --detect current buildsystem
    for _, data in pairs(M.buildSystems) do
        if data.detect ~= nil and data.detect() then
            vim.g.projectBuildSystem = data
            break
        end
    end

    --load new buildsystem
    if
        vim.g.projectBuildSystem ~= nil
        and vim.g.projectBuildSystem.load ~= nil
    then
        vim.g.projectBuildSystem.load()
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

return M
