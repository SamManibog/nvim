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

--- Check if a directory exists in this path
local function isDirectory(path)
   return isDirectoryEntry(path.."/")
end

--------------------------------------------------------------------
--BuildSystem data
--------------------------------------------------------------------

local bs = {}

bs["cmake"] = {
    detect = function()
        return isDirectoryEntry(vim.fn.getcwd().. "/CMakeLists.txt")
    end,
}

bs["cargo"] = {
    detect = function()
        return isDirectoryEntry(vim.fn.getcwd().. "/Cargo.toml")
    end,
}

for key, value in pairs(bs) do
    value["name"] = key
end

M.buildSystems = bs

--------------------------------------------------------------------
--Module Functions
--------------------------------------------------------------------

--refreshes the global projectBuildSystem variable
function M.refreshBuildsystem()
    for buildSystem, data in pairs(M.buildSystems) do
        if data.detect ~= nil and data.detect() then
            vim.g.projectBuildSystem = buildSystem
            return
        end
    end
    vim.g.projectBuildSystem = nil
end

function M.recognizedBuildSystems()
    local list = {}
    local index = 0
    for buildsystem, data in pairs(M.buildSystems) do
        list[index] = data.name
        index = index + 1
    end
    return list
end

return M
