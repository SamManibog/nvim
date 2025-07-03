local M = {}

---determines if a string is a valid name for an action group
---@param name string the string to check if it is a valid name
---@return boolean is_valid whether or not name is valid
function M.isValidGroupName(name)
    return name:match("[^%w_ ]") == nil
end

---determines if a string is a valid name for a config descriptor 
---@param name string the string to check if it is a valid name
---@return boolean is_valid whether or not name is valid
function M.isValidConfigName(name)
    return name:match("[^%w_ ]") == nil
end

---creates a directory at the given path if it doesn't already exist
---@param path string the path at which to make the directory (no parents created)
function M.mkdir(path)
    if not vim.fn.isdirectory(path) then
        vim.uv.fs_mkdir(path, tonumber("777", 8))
    end
end

---detects if the current working directory belongs to a cmake buildsystem
function M.detectCmake()
    return vim.fn.filereadable(vim.fn.getcwd().."/CMakeLists.txt") == 1
end

---detects if the current working directory belongs to a cargo buildsystem
function M.detectCargo()
    return vim.fn.filereadable(vim.fn.getcwd().. "/Cargo.toml") == 1
end


return M
