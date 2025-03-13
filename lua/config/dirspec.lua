local M = {}

local utils = require("config.utils")

---@class DirEntry a representation of some sub directory
---@field name string the name of the file including possible extensions (but not the path)
---@field text (string | fun(opts: table):string)? text contents (files only)
---@field entries (DirEntry[] | fun(opts: table):DirEntry[])? entry contents (folders only)

---creates the given directory an all of its contents as a child of the given path
---@param dir_entry DirEntry the directory entry to use as a template
---@param path string the path at which to create the directory
---@param opts table? a table of options to be called by contents functions
function M.create(dir_entry, path, opts)
    if opts == nil then
        opts = {}
    end
    if utils.isDirectory(path) then
        if type(dir_entry.entries) ~= "nil" then
            ---@type DirEntry[]
            local entries
            if type(dir_entry.entries) == "function" then
                entries = dir_entry.entries(opts)
            else
                entries = dir_entry.entries --[[@as DirEntry[] ]]
            end

            local dir_name = path.."/"..dir_entry.name

            if utils.isDirectoryEntry(dir_name) then
                error("file "..dir_name.." already exists")
            end

            vim.uv.fs_mkdir(dir_name, tonumber("777", 8))

            ---@type _, DirEntry
            for _, entry in pairs(entries) do
                M.create(entry, dir_name, opts)
            end
        else
            ---@type string
            local text
            if type(dir_entry.text) == "function" then
                text = dir_entry.text(opts)
            else
                text = dir_entry.text --[[@as string]]
            end

            local file_name = path.."/"..dir_entry.name

            if utils.isDirectoryEntry(file_name) then
                error("file "..file_name.." already exists")
            end

            local file = io.open(file_name, "w")
            if file ~= nil then
                file:write(text)
                file:close()
            else
                error("unable to create file "..file_name)
            end
        end
    else
        error(path.." is not a valid directory")
    end
end

return M
