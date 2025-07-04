local Popup = require("oneup.popup")

---@alias Option { text: string, is_title?: boolean, [any]: any }

---@alias TitleAlign
---| '"left"'
---| '"center"'
---| '"right"'

---@class OptionsPopup: Popup
---@field private current integer               the currently selected option
---@field private options Option[]              a list of options
---@field private mark_id integer               the id of the ext mark used to highlight the current selection
---@field private title_marks integer[]         a list of extmark ids corresponding to titles (used to keep them aligned)
---@field private title_rows integer[]          a list of rows corresponding to each title mark
---@field private title_widths integer[]        a list of widths for each separator
---@field private title_align TitleAlign|integer either a number or title align
---@field private update_titles fun(self: OptionsPopup)
local OptionsPopup = {}
OptionsPopup.__index = OptionsPopup
setmetatable(OptionsPopup, Popup)

local dividerText = string.rep("-", 256)

---@class OptionsPopupOpts
---@field title string?         the title to display on the popup, useless if border is not true
---@field options Option[]      A list of options that may be selected from
---@field height AdvLength|length
---@field width AdvLength|length
---@field separator_align TitleAlign|integer? either a number or title align to align separator titles to
---@field border boolean?       border?
---@field persistent boolean?   Whether or not the popup will persist once window has been exited
---@field on_close function?    function to run when the popup is closed

---@param opts OptionsPopupOpts the options for the given popup
---@param enter boolean whether or not to immediately focus the popup
function OptionsPopup:new(opts, enter)
    local menuText = {}
    local titles = {}
    local title_widths = {}
    do
        local row = 0
        for _, option in pairs(opts.options) do
            if option.is_title then
                table.insert(titles, row)
            end
            table.insert(menuText, option.text)
            table.insert(title_widths, #option.text)
            row = row + 1
        end
    end

    if #titles == #opts.options then
        error("Options menu must have a non-title option")
    end

    --@type PopupOpts
    local popupOpts = {
        text = menuText,
        focusable = true,
        modifiable = false,

        title = opts.title,
        width = opts.width,
        height = opts.height,
        border = opts.border,
        persistent = opts.persistent,
        on_close = opts.on_close,
    }

    ---@class OptionsPopup
    local p = Popup:new(popupOpts, enter)
    p.options = opts.options
    p.title_align = opts.separator_align or 0
    p.title_widths = title_widths
    p.title_rows = titles
    p.title_marks = {}

    setmetatable(p, self)

    local ns = vim.api.nvim_create_namespace("oneup_options_popup")
    vim.api.nvim_win_set_hl_ns(p:winId(), ns)

    --highlight titles
    for _, row in pairs(titles) do
        vim.api.nvim_buf_set_extmark(
            p:bufId(),
            ns,
            row,
            0,
            {
                line_hl_group = "Title",
                virt_text = { { dividerText, "Title" } },
                virt_text_pos = "eol",
                virt_text_hide = true
            }
        )
        table.insert(p.title_marks,
            vim.api.nvim_buf_set_extmark(
                p:bufId(),
                ns,
                row,
                0,
                {
                    virt_text = { { "", "Title" } },
                    virt_text_pos = "inline"
                }
            )
        )
    end
    p:update_titles()

    --create selected highlight

    p.mark_id = vim.api.nvim_buf_set_extmark(
        p:bufId(),
        ns,
        0,
        0,
        {
            line_hl_group = "PmenuSel"
        }
    )

    p.current = 0
    p:next_option()

    return p
end

---resizes the popup
function OptionsPopup:resize()
    Popup.resize(self)
    self:update_titles()
end

---returns the currently selected option in the popup. useful for keybinds
---@return Option option
function OptionsPopup:get_option()
    return self.options[self.current]
end

---iterates forward to the next option in the popup
function OptionsPopup:next_option()
    self.current = self.current + 1

    if self.current > #self.options then
        self.current = 0
        self:next_option()
    elseif self.options[self.current].is_title then
        self:next_option()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:bufId(),
            vim.api.nvim_create_namespace("oneup_options_popup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:winId(), {self.current, 0})
    end
end

---iterates backward to the previous option in the popup
function OptionsPopup:prev_option()
    self.current = self.current - 1

    if self.current <= 0 then
        self.current = #self.options + 1
        self:prev_option()
    elseif self.options[self.current].is_title then
        self:prev_option()
    else
        self.mark_id = vim.api.nvim_buf_set_extmark(
            self:bufId(),
            vim.api.nvim_create_namespace("oneup_options_popup"),
            self.current - 1,
            0,
            {
                id = self.mark_id,
                line_hl_group = "PmenuSel"
            }
        )
        vim.api.nvim_win_set_cursor(self:winId(), {self.current, 0})
    end
end

function OptionsPopup:update_titles()
    local ns = vim.api.nvim_create_namespace("oneup_options_popup")

    ---@type integer
    local base = 0
    local center = false
    local right = false
    local tail = " "
    if type(self.title_align) == "string" then
        if self.title_align == "center" then
            base = math.floor(self:getWidth() / 2) - 1
            center = true
        elseif self.title_align == "right" then
            base = self:getWidth() - 1
            right = true
        end
    elseif self.title_align <= -1 then
        right = true
        base = self:getWidth() + self.title_align - 1
    else
        base = self.title_align - 1
        if base <= 0 then
            tail = ""
            base = base + 1
        end
    end

    for idx, _ in ipairs(self.title_marks) do
        local text = ""
        if center then
            text = string.rep("-", base - math.floor(self.title_widths[idx] / 2.0)) .. tail
        elseif right then
            text = string.rep("-", base - self.title_widths[idx]) .. tail
        else
            text = string.rep("-", base) .. tail
        end

        vim.api.nvim_buf_set_extmark(
            self:bufId(),
            ns,
            self.title_rows[idx],
            0,
            {
                id = self.title_marks[idx],
                virt_text = { { text, "Title" } },
                virt_text_pos = "inline"
            }
        )
    end
end

OptionsPopup.set_text = nil
OptionsPopup.set_modifiable = nil

return OptionsPopup
