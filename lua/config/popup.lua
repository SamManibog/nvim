local M = {}

---Sets a options from a table for a given buffer
---@param buf_id number
---@param opts table
local function set_buf_opts(buf_id, opts)
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

---@class Popup
---@field private buf_id number
---@field private win_id number
---@field private opts PopupOpts
---@field private closed boolean
---@field private close_aucmd number?
---@field private resize_aucmd number?
M.Popup = {}
M.Popup.__index = M.Popup

---@class PopupOpts
---@field text string[]         text to display on the popup as a list of lines
---@field title string?         the title to display on the popup, useless if border is not true
---@field width number?         the minimum width excluding the border
---@field height number?        the minimum height excluding the border
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited

---Calculates the dimensions of a popup based on the provided text
---@param opts PopupOpts    Popup options
---@return number, number The width, height of the main popup display
local function calculate_dimensions(opts)
    ---@type number
    local height = opts.height or 1
    if opts.text ~= nil then
        height = math.max(height, #opts.text)
    end

    --find width
    ---@type number
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

        if self.close_aucmd ~= nil then
            vim.api.nvim_del_autocmd(self.close_aucmd)
            vim.api.nvim_del_autocmd(self.resize_aucmd)
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
    set_buf_opts(self.buf_id, {
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

    set_buf_opts(self.buf_id, {
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
    ---@type number
    local buffer = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(
        buffer,
        0,
        -1,
        true,
        opts.text or {""}
    )

    set_buf_opts(buffer, {
        modifiable = false,
        bufhidden = "wipe",
        buftype = "nowrite",
        swapfile = false
    })

    --create window
    ---@type number
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

return M
