local M = {}

---determines if a string is a valid name for a config descriptor, group name, or group field name
---@param name string the string to check if it is a valid name
---@return boolean is_valid whether or not name is valid
function M.isValidName(name)
    return #name >= 1 and #name <= 24 and name:match("[^%w_ ]") == nil
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

---gets the default profile for a given configuration
---@param fields ConfigField[]
---@return table
function M.getDefaultProfile(fields)
    local out = {}
    for _, field in ipairs(fields) do
        local value
        if type(field.default) == "function" then
            value = field.default()
        else
            value = field.default
        end

        if field.type == "option" then
            out[field.name] = value[1]
        else
            out[field.name] = value
        end
    end
    return out
end

---@type string[]
local path_hash_valid_characters = {}
for char in string.gmatch("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ123456789", ".") do
    table.insert(path_hash_valid_characters, char)
end
local path_hash_size = #path_hash_valid_characters

---gets the hashed data folder name for the given path
---this function should not be used for encryption
---@param path string the path to find the hashed folder name for
---@return string hash the name of the data folder
function M.getPathHash(path)
    ---@type integer
    local reads = 32

    ---@type integer
    local read_length = math.max(math.floor(#path / reads), 1)
    local extras = #path - (reads * read_length)

    --convert the path into a string with 24 characters
    ---@type string
    local hash = ""

    ---@type integer
    local read_index = 1
    while reads > 0 and #path >= read_index do
        ---@type integer
        local raw = 0

        ---@type integer
        local char_reads = read_length
        if reads <= extras then
            char_reads = char_reads + 1
        end
        while char_reads > 0 do
            raw = raw + string.byte(path, read_index, read_index)
            char_reads = char_reads - 1
            read_index = read_index + 1
        end

        hash = hash..path_hash_valid_characters[math.fmod(raw, path_hash_size) + 1]

        reads = reads - 1
    end

    if #path < read_index then
        hash = hash..string.rep("a", reads)
    end

    return hash
end

---creates a directory at the given path if it doesn't already exist
---@param path string the path at which to make the directory (no parents created)
function M.mkdir(path)
    if vim.fn.isdirectory(path) ~= 1 then
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
