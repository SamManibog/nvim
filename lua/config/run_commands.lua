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

M["cpp"] = function()
    print("not yet implemented")
end

M["java"] = function(args)
    local path = vim.fn.expand('%:s')
    path = "\"" .. path .. "\""
    --local relativePath = vim.fn.expand('%:.:s')
    local classPackage = vim.fn.expand('%:r:.:s')
    classPackage = string.sub(
        classPackage,
        5, --bypass src/
        string.len(classPackage)
    )
    classPackage = "\"" .. classPackage .. "\""
    local classSourcePath = "\"" .. vim.fn.getcwd() .. "/src\""
    local classBinaryPath = "\"" .. vim.fn.getcwd() .. "/bin\""

    local command = ":terminal cd \"" .. vim.fn.getcwd()
    .. "\" && javac --class-path=".. classSourcePath
    .. " " .. path
    .. " -d " .. classBinaryPath
    .. " && java --class-path=" .. classBinaryPath
    .. " " .. classPackage

    vim.cmd("tabnew")
    vim.cmd(command)
    --[[print("path: " .. path)
    print("relpath: " .. relativePath)
    print("pack: " .. classPackage)
    print("srcpath: " .. classSourcePath)
    print("binpath: " .. classBinaryPath)]]
    print(command)
end


M["cs"] = function()
    print("not yet implemented")
end

return M
