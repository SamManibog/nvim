local M = {}

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

--detect if project uses cmake as a buildsystem
M["cmake"] = function()
    return isDirectoryEntry(vim.fn.getcwd().. "/CMakeLists.txt")
end

--detect if project uses cargo as a buildsystem
M["cargo"] = function()
    return isDirectoryEntry(vim.fn.getcwd().. "/Cargo.toml")
end

return M
