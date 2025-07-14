local M = {}

---determines if a string is a valid name for a config descriptor, group name, or group field name
---@param name string the string to check if it is a valid name
---@return boolean is_valid whether or not name is valid
function M.isValidName(name)
    return #name >= 1 and #name <= 24 and name:match("[^%w_ ]") == nil
end

---decodes a json file, outputting a table representing the file
---if the file cannot be opened or contains invalid json, returns nil
---@param path string the path of the json file
---@return any
function M.safeJsonDecode(path)
    if vim.fn.filereadable(path) == 1 then
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

---Open neovim's terminal emulator in a new tab and run a command
---@param cmd string the commmand + any arguments
function M.runInTerminal(cmd)
    vim.cmd("tabnew")
    pcall(vim.cmd, "terminal " .. cmd)
    pcall(vim.cmd, "startinsert")
end

---gets the default profile for a configuration given a list of fields
---@param fields ConfigField[]
---@return table
function M.getDefaultProfile(fields)
    local out = {}
    for _, field in ipairs(fields) do
        if type(field.default) == "function" then
            out[field.name] = field.default()
        else
            out[field.name] = field.default
        end
    end
    return out
end

---recursively and forcibly removes whatever is found at the given path
---@param path string the path to remove
function M.rmrf(path)
    if vim.uv.fs_stat(path) ~= nil then
        vim.fn.delete(path, "rf")
    end
end

---removes the file at the given path
---@param path string the path of the file to remove
function M.rm(path)
    if vim.uv.fs_stat(path) ~= nil then
        vim.fn.delete(path, "")
    end
end

---removes the directory at the given path if it is empty
---@param path string the path of the file to remove
function M.rmdir(path)
    if vim.uv.fs_stat(path) ~= nil then
        vim.fn.delete(path, "d")
    end
end

---creates a directory at the given path if it doesn't already exist
---@param path string the path at which to make the directory (no parents created)
function M.mkdir(path)
    if vim.fn.isdirectory(path) ~= 1 then
        vim.uv.fs_mkdir(path, tonumber("777", 8))
    end
end

---gets a list of all files or directories that satisfy the given function, searching recursively from the given path
---@param path string the path from which to start the search
---@param detect fun(path: string): boolean the function used to detect if a path should be listed
---@param whitelist? fun(path: string): boolean the function used to detect if a given directory should be included in the search
---@param depth? integer the maximum depth to search for files a depth of 0 means only the given path will be searched
---@param count? integer the maximum number of entries to return
function M.listFiles(path, detect, whitelist, depth, count)
    if count == nil then count = math.huge end
    if depth == nil then depth = math.huge end
    if whitelist == nil then whitelist = function(_) return true end end
    if path:sub(-1):match("[/\\]") then path = path:sub(0, -2) end

    ---@type string[]
    local queue1 = {}

    ---@type string[]
    local queue2 = {}

    ---@type string[]
    local out = {}

    ---@type integer
    local out_size = 0

    ---@type integer
    local search_depth = 1

    if depth >= 0 and count > 0 then
        local fs = vim.uv.fs_scandir(path)

        for name, type in function() return vim.uv.fs_scandir_next(fs) end do
            local full_path = path.."/"..name
            if type == "directory" and whitelist(full_path) then
                table.insert(queue1, "/"..name)
            end
            if detect(full_path) then
                table.insert(out, "/"..name)
                out_size = out_size + 1
                if out_size >= count then return out end
            end
        end
    else
        return out
    end

    while #queue1 > 0 and search_depth <= depth do
        while #queue1 > 0 do
            local rel_path = queue1[#queue1]
            local fs = vim.uv.fs_scandir(path..rel_path)
            queue1[#queue1] = nil

            for name, type in function() return vim.uv.fs_scandir_next(fs) end do
                local full_path = path..rel_path.."/"..name
                if type == "directory" and whitelist(full_path) then
                    table.insert(queue2, rel_path.."/"..name)
                end
                if detect(full_path) then
                    table.insert(out, rel_path.."/"..name)
                    out_size = out_size + 1
                    if out_size >= count then return out end
                end
            end
        end

        search_depth = search_depth + 1

        queue1 = queue2
        queue2 = {}
    end

    return out
end

return M
