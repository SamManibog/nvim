local M = {}

---determines if a string is a valid name for a config descriptor, group name, or group field name
---@param name string the string to check if it is a valid name
---@return boolean is_valid whether or not name is valid
function M.isValidName(name)
    return name:match("[^%w_ ]") == nil
end

---decodes a json file, outputting a table representing the file
---if the file contains invalid json, returns nil
---@param path string the path of the json file
---@return any
function M.safeJsonDecode(path)
    if vim.fn.filereadable(path) == true then
        local output
        local decode = function()
            output = vim.fn.json_decode(vim.fn.readfile(path))
        end

        if pcall(decode) then
            return output
        else
            return nil
        end
    else
        return nil
    end
end

---Run a command in the terminal emulator
---@param cmd string the commmand + any arguments
function M.runInTerminal(cmd)
    vim.cmd("tabnew")
    pcall(vim.cmd, "terminal " .. cmd)
    pcall(vim.cmd, "startinsert")
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
