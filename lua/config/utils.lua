local M = {}

local diagnosticSeverityMap = {
    "ERROR",
    "WARNING",
    "INFO",
    "HINT",
}

function M.gotoFirstDiagnostic(bufnr, severity)
    local diags = {}
    if severity then
        diags = vim.diagnostic.get(bufnr, { severity = severity })
    else
        diags = vim.diagnostic.get(bufnr)
    end

    local first = diags[1]
    if first == nil then
        print("No diagnostic found")
        return
    end

    vim.api.nvim_win_set_cursor(
        0,
        {
            first.lnum + 1,
            first.col
        }
    )

    print(diagnosticSeverityMap[severity] .. ": " .. first.message)
end

function M.toggleTerminal()
    if vim.bo.buftype == "terminal" then
        vim.cmd("bdelete!")
        --vim.cmd("q")
        return
    end
    vim.cmd("tab split")
    vim.cmd("terminal")
    vim.cmd("startinsert")
end

-- Trim whitespace from both ends of a string
function M.trim(s)
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

-- Check if a file or directory exists in this path
function M.isDirectoryEntry(path)
    return vim.uv.fs_stat(path) ~= nil
end

-- Check if the path is a valid directory
function M.isDirectory(path)
    local entry = vim.uv.fs_stat(path)
    return entry ~= nil and entry.type == "directory"
end

-- Check if the path is a valid executable
function M.isExecutable(path)
    local entry = vim.uv.fs_stat(path)
    return entry ~= nil and vim.fn.executable(path) == 1
end

-- Run a command in the terminal emulator
function M.runInTerminal(args)
    vim.cmd("tabnew")
    pcall(vim.cmd, "terminal " .. args)
    pcall(vim.cmd, "startinsert")
end

---Sets a options from a table for a given buffer
---@param buf_id number
---@param opts table
function M.set_buf_opts(buf_id, opts)
    for option, value in pairs(opts) do
        vim.api.nvim_set_option_value(
            option,
            value,
            {
                buf = buf_id
            }
        )
    end
end

---inserts found files into table
---@param dir string
---@param depth number
---@param exes table
---@param ignore { file: nil|(fun(path: string): boolean), directory: nil|(fun(path: string): boolean) }
local function get_files_helper(dir, depth, exes, ignore)
    local iter = vim.uv.fs_scandir(dir)
    local name, type = vim.uv.fs_scandir_next(iter)
    while name ~= nil do
        if type == "directory"
            and depth ~= 0
            and not ignore.directory(dir .. "/" .. name)
        then
            get_files_helper(dir .. "/" .. name, depth - 1, exes, ignore)

        elseif not ignore.file(dir .. "/" .. name) then
            table.insert(
                exes,
                {
                    name = name,
                    full_path = dir .. "/" .. name,
                }
            )
        end
        name, type = vim.uv.fs_scandir_next(iter)
    end
end

---Returns a table with all executables in a file tree (designed for cmake builds)
---@param path string|nil   the first directory to search
---@param depth number|nil  the depth to search, leave nil or negative to not limit depth
---@param ignore {file: nil|(fun(path: string): boolean), directory: nil|(fun(path: string): boolean)} dont search files or directories for which these functions return true
---@return { name: string, full_path: string, relative_path: string }[]
function M.get_files(path, depth, ignore)
    path = path or vim.fn.getcwd()
    depth = depth or -1
    ignore = ignore or {
        file = function() return false end,
        directory = function() return false end
    }

    local out = {}

    if M.isDirectory(path) then
        get_files_helper(path, depth, out, ignore)

        for _, value in pairs(out) do
            value.relative_path = string.sub(value.full_path, string.len(path) + 2)
        end
    end

    return out
end

function test()
    local exes = M.get_files(vim.fn.getcwd() .. "/build", nil,
        {
            file = function(path)
                return not M.isExecutable(path)
            end,
            directory = function(path)
                local name = vim.fn.fnamemodify(path, ":t")
                return name == ".cmake" or name == "CMakeFiles"
            end
        }
    )

    for _, value in pairs(exes) do
        print(value.name)
        print("\trel path: " .. value.relative_path)
        print("\tfull path: " .. value.full_path .. "\n")
    end
end

return M
