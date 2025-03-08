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

-- Run a command in the terminal emulator
function M.runInTerminal(args)
    vim.cmd("tabnew")
    vim.cmd("terminal " .. args)
    vim.cmd("startinsert")
end

return M
