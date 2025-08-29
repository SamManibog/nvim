local M = {}

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

---generates a command using a table given list of config fields to be used as keys
---important fields in the configField type are
--- - cmd_omit      if this is true, the field will not be used in command generation
--- - omit_default  if the table value is the default value in the config field, writing the argument is skipped
--- - arg_prefix    used to prefix the value found in the config
--- - arg_postfix   used to post the value found in the config
--- - list_affix    if true and the type is a list, arg_prefix and arg_postfix will be used between every element on the list (default is surrounding the entire list)
--- - show_empty    if true and the type is a list, option, or string, pre and postfix will be appended to the command even if the string value is empty.
--- - bool_display  if the type is a boolean and this is not nil, instead of the normal format, [prefix][postfix] will be appended to the command if bool_display matches the config's value
---@param head string the main command
---@param config table the table containing keys specified by fields
---@param fields ConfigField[] a list of fields used as the specification for generating a command
---@return string command a command in the format [head] [arg1_prefix][arg1][arg1_postfix] [arg2_prefix][arg2][arg2_postfix]...
function M.generateCommand(head, config, fields)
    local cmd = head
    for _, field in ipairs(fields) do
        ---@type boolean
        local generate = not field.cmd_omit
        if field.omit_default and generate then
            local default
            if type(field.default) == "function" then
                default = field.default()
            else
                default = field.default
            end

            if field.type == "list" then
                if #default == #config[field.name] then
                    generate = false
                else
                    for idx, value in ipairs(default) do
                        if value ~= default.value[idx] then
                            generate = true
                            break
                        end
                    end
                    generate = false
                end
            else
                generate = default ~= config[field.name]
            end
        else
            generate = true
        end

        local value = config[field.name]

        local pre = field.arg_prefix or " "
        local post = field.arg_postfix or ""

        if field.custom_cmd ~= nil then
            cmd = cmd.." "..pre..field.custom_cmd(value)..post
        elseif field.type == "list" and field.list_affix then
            for _, entry in ipairs(value) do
                cmd = cmd.." "..pre..entry..post
            end
        elseif field.type == "list" then
            cmd = cmd.." "..pre
            for _, entry in ipairs(value) do
                cmd = cmd.." "..entry
            end
            cmd = cmd..post
        elseif field.type == "boolean" and field.bool_display ~= nil then
            if value == field.bool_display then
                cmd = cmd.." "..pre..post
            end
        else
            cmd = cmd.." "..pre..tostring(value)..post
        end
    end

    return cmd
end

---creates a directory at the given path if it doesn't already exist
---(convenient as vim function throws an error if directory exists)
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
---@return string[]
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

        if fs == nil then error("'"..path.."' is not a directory.") end

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

            if fs == nil then error("'"..path.."' is not a directory.") end

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

---@type number?
local term_job

---@type number?
local term_job_buffer

---@return boolean
function M.terminalIsOpen()
    return term_job ~= nil and term_job_buffer ~= nil
end

function M.forceKillTerminal()
    if term_job ~= nil then
        vim.fn.jobstop(term_job)
    end
    term_job = nil
    term_job_buffer = nil
end

---@return boolean new_created returns true if a new terminal buffer was created and false otherwise
function M.openTerminal()
    if M.terminalIsOpen() then
        if vim.fn.bufnr ~= term_job_buffer then
            local wins = vim.api.nvim_tabpage_list_wins(0)
            for _, win_id in ipairs(wins) do
                if vim.api.nvim_win_get_buf(win_id) == term_job_buffer then
                    vim.api.nvim_tabpage_set_win(0, win_id)
                    vim.cmd.wincmd("J")
                    vim.cmd.startinsert()
                    return false
                end
            end
            vim.cmd.vnew()
            vim.cmd.buffer(term_job_buffer)
            vim.cmd.wincmd("J")
        end
        if vim.fn.mode() ~= "t" then
            vim.cmd.startinsert()
        end
        return false
    else
        vim.cmd.vnew()
        vim.cmd.terminal()
        term_job = vim.bo.channel
        term_job_buffer = vim.fn.bufnr("%")
        vim.api.nvim_create_autocmd("BufWipeout", {
            group = vim.api.nvim_create_augroup("director-terminal", { clear = true}),
            buffer = term_job,
            callback = function()
                print("term killed")
                term_job = nil
                term_job_buffer = nil
            end
        })
        vim.cmd.wincmd("J")
        vim.cmd.startinsert()
        return true
    end
end

---@param cmd string the command to run in the terminal
function M.runInTerminal(cmd)
    if not M.openTerminal() then
        vim.fn.chansend(term_job, "\3") ---@diagnostic disable-line:param-type-mismatch openTerminal function guarantees term_job is non-nil
    end

    vim.fn.chansend(term_job, { cmd, "" }) ---@diagnostic disable-line:param-type-mismatch
end

---closes the terminal if currently on the terminal
---opens the terminal if not on the terminal
function M.toggleTerminal()
    if vim.fn.bufnr() == term_job_buffer then
        vim.cmd.quit()
    else
        M.openTerminal()
    end
end

return M
