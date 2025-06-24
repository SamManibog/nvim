local M = {}

local utils = require("config.utils")

---@class Popup
---@field private buf_id integer
---@field private win_id integer
---@field private opts PopupOpts
---@field private closed boolean
---@field private close_aucmd integer?
---@field private resize_aucmd integer?
M.Popup = {}
M.Popup.__index = M.Popup

---@class PopupOpts
---@field text string[]         text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width integer?        the minimum width excluding the border
---@field height integer?       the minimum height excluding the border
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited

---Calculates the dimensions of a popup based on the provided text
---@param opts PopupOpts    Popup options
---@return integer, integer The width, height of the main popup display
local function calculate_dimensions(opts)
    ---@type integer
    local height = opts.height or 1
    if opts.text ~= nil then
        height = math.max(height, #opts.text)
    end

    --find width
    ---@type integer
    local width = opts.width or 1
    if opts.title ~= nil then
        width = math.max(width, #opts.title)
    end
    if opts.text ~= nil then
        for _, line in ipairs(opts.text) do
            width = math.max(width, #line)
        end
    end

    return width, height
end

function M.Popup:close()
    if not self.closed then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true

        --if statement protects against :q being used
        if vim.api.nvim_win_is_valid(self.win_id) then
            vim.api.nvim_win_close(self.win_id, true)
        end

        --destroy associated autocommands
        if self.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.close_aucmd)
            self.close_aucmd = nil
        end
        if self.resize_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.resize_aucmd)
            self.resize_aucmd = nil
        end
    end
end

function M.Popup:resize()
    local width, height = calculate_dimensions(self.opts)

    local row = math.floor(((vim.o.lines - height) / 2) - 1)
    local col = math.floor((vim.o.columns - width) / 2)
    col = math.max(0, col)
    row = math.max(1, row)

    vim.api.nvim_win_set_config(
        self.win_id,
        {
            relative = "editor",
            row = row,
            col = col,
            width = width,
            height = height,
        }
    )
end

---sets the text of the popup
---@param text string[]
function M.Popup:set_text(text)
    utils.set_buf_opts(self.buf_id, {
        modifiable = true,
    })

    self.opts.text = text
    vim.api.nvim_buf_set_lines(
        self.buf_id,
        0,
        -1,
        true,
        self.opts.text or {""}
    )
    self:resize()

    utils.set_buf_opts(self.buf_id, {
        modifiable = false,
    })
end

function M.Popup:get_win_id()
    return self.win_id
end

function M.Popup:get_buf_id()
    return self.buf_id
end

---Creates a new popup
---@param opts PopupOpts
function M.new(opts)
    local width, height = calculate_dimensions(opts)

    --create buffer
    ---@type integer
    local buffer = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(
        buffer,
        0,
        -1,
        true,
        opts.text or {""}
    )

    utils.set_buf_opts(buffer, {
        modifiable = false,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false
    })

    --create window
    ---@type integer
    local window = vim.api.nvim_open_win(
        buffer,
        true,
        {
            relative = "editor",
            row = 10,
            col = 10,
            width = width,
            height = height,
            focusable = true,
            zindex = 99,
            style = "minimal",
        }
    )

    if opts.border then
        local config = {
            border = "rounded"
        }
        if opts.title then
            config.title = " "..opts.title.." "
            config.title_pos = "center"
        end
        vim.api.nvim_win_set_config(
            window,
            config
        )
    end


    --create final object
    ---@type Popup
    local out

    local close_aucmd = nil
    --create closing autocommand
    if not opts.persistent then
        close_aucmd = vim.api.nvim_create_autocmd(
            {
                "BufEnter",
                "UIEnter",
                "TabEnter",
                "WinEnter",
                "BufHidden",
                "BufWipeout",
                "BufLeave",
                "BufWinLeave",
            },
            {
                callback = function ()
                    out:close()
                end
            }
        )
    end

    --create resize autocommand
    local resize_aucmd = vim.api.nvim_create_autocmd(
        {
            "VimResized"
        },
        {
            callback = function ()
                out:resize()
            end
        }
    )

    ---@diagnostic disable-next-line: missing-fields
    out = {
        buf_id = buffer,
        win_id = window,
        opts = opts,
        closed = false,
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
    }
    setmetatable(out, M.Popup)
    out:resize()

    return out
end

---@class AdvInputPopup
---@field private prompt_buf_id integer     buf id for the prompt buffer
---@field private prompt_win_id integer     win id for the prompt buffer window
--the input being handled
---@field private inputting {
---row: integer, 
---buf_id: integer, 
---win_id: integer,
---close_aucmd: integer?}?
---@field private prompt_width integer      the length of the prompt portion of the window
---@field private opts AdvInputPopupOpts    the options used in managing the buffer
---@field private closed boolean            whether or not the window has been closed
---@field private close_aucmd integer?      the autocommand id for handling closing the window
---@field private resize_aucmd integer?     the autocommand id for handling resizing the window
---@field private allow_swap boolean        swap whiteless for creation of input buffer
---@field inputs {[string]: string}         the inputs given to the popup
M.AdvInputPopup = {}
M.AdvInputPopup.__index = M.AdvInputPopup

---@class AdvInputPopupOpts
---@field prompts string[]                  prompts to display as a collection of key, prompt pairs
---@field title string?                     the title to display on the popup, useless if border is not true
---@field width integer?                    the width of the input buffer
---@field border boolean?                   border?
---@field verify_input {
---[string]: fun(text:string):boolean}?     table of functions used to verify input for a given prompt
---@field on_confirm fun(inputs:{[string]: string}) callback for after input has been confirmed

---@param opts AdvInputPopupOpts
---@return {prompt_width: integer, width: integer, height: integer}
local function calculate_input_dimensions(opts)
    local out = {}
    local prompt_count = 0
    out.prompt_width = 1 --min input width of 1
    for _, prompt in pairs(opts.prompts) do
        out.prompt_width = math.max(out.prompt_width, #prompt)
        prompt_count = prompt_count + 1
    end
    out.prompt_width = math.max(out.prompt_width, #"confirm: ")
    out.prompt_width = out.prompt_width + 2 --+2 for ": "
    out.width = out.prompt_width + opts.width
    out.height = prompt_count + 1 --+1 for confirm prompt
    return out
end

function M.AdvInputPopup:resize()
    local dim = calculate_input_dimensions(self.opts)

    local row = math.floor(((vim.o.lines - dim.height) / 2) - 1)
    local col = math.floor((vim.o.columns - dim.width) / 2)
    col = math.max(0, col)
    row = math.max(1, row)

    vim.api.nvim_win_set_config(
        self.prompt_win_id,
        {
            relative = "editor",
            row = row,
            col = col,
            width = dim.width,
            height = dim.height,
        }
    )
    if self.inputting ~= nil then
        vim.api.nvim_win_set_config(
            self.inputting.win_id,
            {
                relative = "editor",
                row = row + self.inputting.row,
                col = col + self.prompt_width + 1,
                width = dim.width - self.prompt_width,
                height = 1,
            }
        )
    end
end

function M.AdvInputPopup:close()
    if not self.closed and not self.allow_swap then
        -- self.closed variable is necessary to prevent double firing
        self.closed = true

        --if statement protects against :q being used
        if vim.api.nvim_win_is_valid(self.prompt_win_id) then
            vim.api.nvim_win_close(self.prompt_win_id, true)
        end

        if self.inputting ~= nil then
            vim.api.nvim_win_close(self.inputting.win_id, true)
        end

        --destroy associated autocommands
        if self.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.close_aucmd)
            self.close_aucmd = nil
        end
        if self.resize_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.resize_aucmd)
            self.resize_aucmd = nil
        end
        if self.inputting ~= nil and self.inputting.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.inputting.close_aucmd)
        end
    end
end

---@param prompts {[string]: string} the list of prompts
---@param responses {[string]: string} the list of inputs to the prompts
---@param width integer the total width of the prompts
---@return string[]     the text for the prompt menu
function M.gen_prompt_text(prompts, responses, width)
    local out = {}
    for _, prompt in pairs(prompts) do
        table.insert(out,
            string.rep(" ", width - #prompt - 2)
            ..prompt
            ..": "
            ..(responses[prompt] or " ")
        )
    end
    table.insert(out,
        string.rep(" ", width - #"confirm: ")
        .."confirm:  "
    )
    return out
end

function M.AdvInputPopup:refresh_text()
    vim.api.nvim_set_option_value(
        "modifiable",
        true,
        {
            buf = self.prompt_buf_id,
        }
    )
    vim.api.nvim_buf_set_lines(
        self.prompt_buf_id,
        0,
        -1,
        true,
        M.gen_prompt_text(self.opts.prompts, self.inputs, self.prompt_width)
    )
    vim.api.nvim_set_option_value(
        "modifiable",
        false,
        {
            buf = self.prompt_buf_id,
        }
    )
end

---Creates a new popup
---@param opts AdvInputPopupOpts
function M.new_adv_input(opts)
    local dim = calculate_input_dimensions(opts)

    --create prompt buffer
    ---@type integer
    local prompt_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(
        prompt_buf,
        0,
        -1,
        true,
        M.gen_prompt_text(opts.prompts, {}, dim.prompt_width)
    )

    utils.set_buf_opts(prompt_buf, {
        modifiable = false,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false
    })

    --create window
    ---@type integer
    local prompt_window = vim.api.nvim_open_win(
        prompt_buf,
        true,
        {
            relative = "editor",
            row = 10,
            col = 10,
            width = dim.width,
            height = dim.height,
            focusable = true,
            zindex = 98,
            style = "minimal",
        }
    )

    if opts.border then
        local config = {
            border = "rounded"
        }
        if opts.title then
            config.title = " "..opts.title.." "
            config.title_pos = "center"
        end
        vim.api.nvim_win_set_config(
            prompt_window,
            config
        )
    end

    --create final object
    ---@type AdvInputPopup
    local out

    local close_aucmd = nil
    --create closing autocommand
    close_aucmd = vim.api.nvim_create_autocmd(
        {
            "BufEnter",
            "UIEnter",
            "TabEnter",
            "WinEnter",
            "BufHidden",
            "BufWipeout",
            "BufLeave",
            "BufWinLeave",
        },
        {
            callback = function ()
                out:close()
            end
        }
    )

    --create resize autocommand
    local resize_aucmd = vim.api.nvim_create_autocmd(
        {
            "VimResized"
        },
        {
            callback = function ()
                out:resize()
            end
        }
    )

    ---@diagnostic disable-next-line: missing-fields
    out = {
        prompt_buf_id = prompt_buf,
        prompt_win_id = prompt_window,
        prompt_width = dim.prompt_width,
        opts = opts,
        closed = false,
        inputs = {},
        close_aucmd = close_aucmd,
        resize_aucmd = resize_aucmd,
        allow_swap = false,
    }
    setmetatable(out, M.AdvInputPopup)
    out:resize()

    for _, char in pairs({"I", "i", "A", "a"}) do
        vim.api.nvim_buf_set_keymap(
            prompt_buf,
            "n",
            char,
            "",
            {
                ---@diagnostic disable: invisible
                callback = function()
                    if out.closed == true then
                        return
                    end
                    --create inputting window

                    --determine position
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local prompt_row = cursor[1]

                    --determine key for prompt input
                    local prompt_key = nil
                    local index = 1 --rows are 1-indexed

                    for key, _ in pairs(out.opts.prompts) do
                        if prompt_row == index then
                            prompt_key = key
                        end
                        index = index + 1
                    end

                    local close_input_buffer = function()
                        vim.api.nvim_del_autocmd(out.inputting.close_aucmd)
                        out.allow_swap = true
                        vim.api.nvim_tabpage_set_win(0, out.prompt_win_id)
                        vim.api.nvim_win_close(out.inputting.win_id, true)
                        out.allow_swap = false
                        out.close_aucmd = nil
                        out.inputting = nil
                    end

                    --create input_buf
                    local input_buf = vim.api.nvim_create_buf(false, true)
                    utils.set_buf_opts(input_buf, {
                        bufhidden = "wipe",
                        buftype = "prompt",
                        swapfile = false
                    })
                    vim.fn.prompt_setprompt(input_buf, "")
                    vim.api.nvim_buf_set_lines(
                        input_buf,
                        0,
                        -1,
                        true,
                        {out.inputs[out.opts.prompts[prompt_row]]} or {""}
                    )

                    --special callback for confirm prompt
                    if prompt_key == nil then
                        vim.fn.prompt_setcallback(input_buf, function (text)
                            if text == nil then
                                print("Use y/n to confirm.")
                            else
                                local c = string.sub(text, 0, 1)
                                if c == "Y" or c == "y" then
                                    --verify inputs
                                    if out.opts.verify_input ~= nil then
                                        for prompt, callback in pairs(out.opts.verify_input) do
                                            if not callback(out.inputs[prompt] or "") then
                                                print("Invalid input given.")
                                                close_input_buffer()
                                                return
                                            end
                                        end
                                    end
                                    out.opts.on_confirm(out.inputs)
                                    out:close()
                                    return
                                elseif c == "N" or c == "n" then
                                    out:close()
                                    return
                                else
                                    print("Use y/n to confirm.")
                                end
                            end
                            close_input_buffer()
                        end)
                    else
                        vim.fn.prompt_setcallback(input_buf, function (text)
                            out.inputs[out.opts.prompts[prompt_row]] = text
                            out:refresh_text()
                            close_input_buffer()
                        end)
                    end

                    out.allow_swap = true

                    local input_dim = calculate_input_dimensions(out.opts)
                    local row = math.floor(((vim.o.lines - input_dim.height) / 2) - 1)
                    local col = math.floor((vim.o.columns - input_dim.width) / 2)
                    local input_win = vim.api.nvim_open_win(
                        input_buf,
                        true,
                        {
                            relative = "editor",
                            row = row + prompt_row,
                            col = col + out.prompt_width + 1,
                            width = dim.width - out.prompt_width,
                            height = 1,
                            focusable = true,
                            zindex = 99,
                            style = "minimal",
                        }
                    )
                    vim.cmd("startinsert!")

                    vim.schedule(function ()
                        local input_close_aucmd = vim.api.nvim_create_autocmd(
                            "ModeChanged",
                            {
                                callback = function()
                                    out.inputs[out.opts.prompts[prompt_row]]
                                    = vim.api.nvim_buf_get_lines(
                                        input_buf,
                                        0,
                                        1,
                                        true
                                    )[1] or ""

                                    out:refresh_text()
                                    close_input_buffer()
                                end
                            }
                        )

                        out.inputting = {
                            row = prompt_row,
                            buf_id = input_buf,
                            win_id = input_win,
                            close_aucmd = input_close_aucmd
                        }
                        out:resize()

                        out.allow_swap = false
                    end)
                end
                ---@diagnostic enable: invisible
            }
        )
    end

    return out
end

---@class InputPopupOpts
---@field text string[]         text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width integer?        the minimum width excluding the border
---@field border boolean?       border?

---@param opts {
---text: string[],
---title: string?,
---width: integer?,
---border: boolean?,
---verify_input: (fun(text:string):boolean)?,
---on_confirm: fun(text:string),
---prompt: string?}
---@return Popup
function M.new_input(opts)
    local base_opts = {}
    base_opts.text = opts.text
    table.insert(base_opts.text,"")
    if opts.title ~= nil then
        base_opts.title = opts.title
    end
    if opts.width ~= nil then
        base_opts.width = opts.width
    end
    if opts.border ~= nil then
        base_opts.border = opts.border
    end
    base_opts.persistent = true

    local base_popup = M.new(base_opts)
    local buf = base_popup:get_buf_id()
    utils.set_buf_opts(
        buf,
        {
            buftype = "prompt",
            modifiable = true
        }
    )
    vim.fn.prompt_setprompt(buf, opts.prompt or "")
    vim.fn.prompt_setcallback(buf,function (text)
        if opts.verify_input ~= nil then
            if not opts.verify_input(text) then
                vim.api.nvim_buf_set_lines(
                    buf,
                    ---@diagnostic disable-next-line: invisible
                    #base_popup.opts.text,
                    -1,
                    false,
                    {}
                )
                vim.cmd("startinsert!")
                print("Invalid input '"..text.."'.")
                return
            end
        end
        opts.on_confirm(text)
        base_popup:close()
    end)
    vim.cmd("startinsert")
    vim.schedule(function ()
        local close_aucmd = vim.api.nvim_create_autocmd(
            {
                "BufEnter",
                "UIEnter",
                "TabEnter",
                "WinEnter",
                "BufHidden",
                "BufWipeout",
                "BufLeave",
                "BufWinLeave",
                "ModeChanged"
            },
            {
                callback = function ()
                    base_popup:close()
                end
            }
        )
        ---@diagnostic disable-next-line: invisible
        base_popup.close_aucmd = close_aucmd
    end)
    return base_popup
end

---@class ActionsMenuOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field width integer?        the minimum width excluding the border
---@field height integer?       the minimum height excluding the border
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field stayOpen boolean?     Whether or not the popup will persist (by default) when an action has been executed
---@field closeBinds string[]?  A list of keybinds that will close the menu

---@param actions { bind: string?, desc: string, persist: boolean|nil, callback: function, [any]: any }[] a list of tables describing the available actions
---@param opts ActionsMenuOpts the options for the given popup
function M.new_actions_menu(actions, opts)
    local menuText = {}

    --determine max length of keybinds to allow right alignment
    local keybind_length = 0
    for _, action in pairs(actions) do
        if action.bind == nil then break end

        keybind_length = math.max(keybind_length, string.len(action.bind))
    end

    local height = 0
    for _, action in pairs(actions) do
        action.line_nr = height + 1

        if action.bind == nil then
            local padding = string.rep(" ", keybind_length + 3)
            table.insert(menuText, padding .. action.desc)
        else
            local padding = string.rep(" ", keybind_length - string.len(action.bind))
            table.insert(menuText, padding .. action.bind .. " - " .. action.desc)
        end

        height = height + 1
    end

    --@type PopupOpts
    local popupOpts = {
        title = opts.title,
        width = opts.width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,

        text = menuText,
    }

    popupOpts["text"] = menuText

    local p = M.new(popupOpts)

    for _, action in pairs(actions) do
        if action.bind == nil then break end

        if opts.stayOpen then
            vim.api.nvim_buf_set_keymap(
                p:get_buf_id(),
                "n",
                action.bind,
                "",
                {
                    silent = true,
                    callback = function()
                        action.callback()
                        if action.persist == false then
                            p:close()
                        end
                    end
                }
            )
        else
            vim.api.nvim_buf_set_keymap(
                p:get_buf_id(),
                "n",
                action.bind,
                "",
                {
                    silent = true,
                    callback = function()
                        action.callback()
                        if not action.persist then
                            p:close()
                        end
                    end
                }
            )
        end
    end

    if opts.closeBinds ~= nil then
        for _, closer in pairs(opts.closeBinds) do
            vim.api.nvim_buf_set_keymap(
                p:get_buf_id(),
                "n",
                closer,
                "",
                {
                    silent = true,
                    callback = function() p:close() end
                }
            )
        end
    end

    return p
end

return M
