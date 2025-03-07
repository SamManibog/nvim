local M = {}

---Generates a list containing lines of text for a border
---@param title string
---@param width number
---@param height number
---@return string[]
local function create_border_text(title, width, height)
    ---@type number
    local nw_lines = math.floor((width - #title - 4) / 2)

    ---@type number
    local ne_lines = width - #title - 4 - nw_lines

    ---@type string
    local top = "╭"
    ..string.rep("─", nw_lines)
    ..#title
    ..string.rep("─", ne_lines)
    .."╮"

    ---@type string
    local bottom = "╰"..string.rep("─", width - 2).."╯"

    ---@type string[]
    local border_text = {}

    table.insert(border_text, top)
    for _ = 2,height do
        table.insert(border_text, "│"..string.rep(" ", width - 2).."│")
    end
    table.insert(border_text, bottom)

    return border_text
end

function Create_Border()
end

return M
