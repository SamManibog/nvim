return {
    "rebelot/heirline.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
    config = function()
        local conditions = require("heirline.conditions")
        local utils = require("heirline.utils")
        local function setup_colors()
            local theme = require("kanagawa.colors").setup().theme
            return {
                bg_1 = theme.ui.bg_p1,
                bg_2 = theme.ui.bg_m1,
                bg_3 = theme.ui.bg_dim,
                fg_1 = theme.ui.fg_dim,
                fg_2 = theme.ui.fg,
                black = theme.term[1],
                red = theme.term[2],
                green = theme.term[3],
                yellow = theme.term[4],
                blue = theme.term[5],
                magenta = theme.term[6],
                cyan = theme.term[7],
                white = theme.term[8],
                bright_black = theme.term[9],
                bright_red = theme.term[10],
                bright_green = theme.term[11],
                bright_yellow = theme.term[12],
                bright_blue = theme.term[13],
                bright_magenta = theme.term[14],
                bright_cyan = theme.term[15],
                bright_white = theme.term[16],
                diag_warn = theme.diag.warning,
                diag_error = theme.diag.error,
                diag_hint = theme.diag.hint,
                diag_info = theme.diag.info,
                git_del = theme.diff.delete,
                git_add = theme.diff.add,
                git_change = theme.diff.change,
            }
        end
        require("heirline").load_colors(setup_colors)

        vim.api.nvim_create_augroup("Heirline", { clear = true })
        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = function()
                utils.on_colorscheme(setup_colors)
            end,
            group = "Heirline",
        })

        local Align = { provider = "%=" }
        local Space = { provider = " " }

        local ViMode = {
            init = function(self)
                self.mode = vim.fn.mode(1) -- :h mode()
            end,
            static = {
                mode_names = { -- change the strings if you like it vvvvverbose!
                    ["n"] = "Normal",
                    ["no"] = "Normal",
                    ["nov"] = "Normal",
                    ["noV"] = "Normal",
                    ["no\22"] = "Normal",
                    ["niI"] = "Normal",
                    ["niR"] = "Normal",
                    ["niV"] = "Normal",
                    ["nt"] = "Normal",
                    ["ntT"] = "Normal",
                    ["v"] = "Visual",
                    ["vs"] = "Visual",
                    ["V"] = "V-Line",
                    ["Vs"] = "V-Line",
                    ["\22"] = "V-Block",
                    ["\22s"] = "V-Block",
                    ["s"] = "Select",
                    ["S"] = "S-Line",
                    ["\19"] = "S-Block",
                    ["i"] = "Insert",
                    ["ic"] = "Insert",
                    ["ix"] = "Insert",
                    ["R"] = "Replace",
                    ["Rc"] = "Replace",
                    ["Rx"] = "Replace",
                    ["Rv"] = "V-Replace",
                    ["Rvc"] = "V-Replace",
                    ["Rvx"] = "V-Replace",
                    ["c"] = "Command",
                    ["cv"] = "Ex",
                    ["ce"] = "Ex",
                    ["r"] = "Replace",
                    ["rm"] = "More",
                    ["r?"] = "Confirm",
                    ["!"] = "Shell",
                    ["t"] = "Terminal",
                },
                mode_colors = {
                    n = "bright_white",
                    i = "bright_green",
                    v = "bright_magenta",
                    V =  "bright_magenta",
                    ["\22"] =  "bright_cyan",
                    c =  "bright_red",
                    s =  "blue",
                    S =  "blue",
                    ["\19"] =  "bright_blue",
                    R =  "yellow",
                    r =  "yellow",
                    ["!"] =  "bright_red",
                    t =  "bright_red",
                }
            },
            provider = function(self)
                return "%2("..self.mode_names[self.mode].."%)"
            end,
            -- Same goes for the highlight. Now the foreground will change according to the current mode.
            hl = function(self)
                local mode = self.mode:sub(1, 1) -- get only the first mode character
                return { fg = self.mode_colors[mode], bold = true, }
            end,
            update = {
                "ModeChanged",
                pattern = "*:*",
                callback = vim.schedule_wrap(function()
                    vim.cmd("redrawstatus")
                end),
            },
        }
        ViMode = utils.surround({"█", "█"}, "bg_1", ViMode)

        local FileNameBlock = {
            -- let's first set up some attributes needed by this component and its children
            init = function(self)
                if vim.fn.mode(1) == "t" then
                    self.filename = "cmd.exe"
                else
                    self.filename = vim.api.nvim_buf_get_name(0)
                end
            end,
        }
        -- We can now define some children separately and add them later

        local FileIcon = {
            init = function(self)
                local filename = self.filename
                local extension = vim.fn.fnamemodify(filename, ":e")
                self.icon, self.icon_color = require("nvim-web-devicons").get_icon_color(
                    filename, extension, { default = true }
                )
            end,
            provider = function(self)
                return self.icon and (" " .. self.icon)
            end,
            hl = function(self)
                return { fg = self.icon_color }
            end
        }

        local FileName = {
            provider = function(self)
                -- first, trim the pattern relative to the current directory. For other
                -- options, see :h filename-modifers
                local filename = vim.fn.fnamemodify(self.filename, ":.")
                if filename == "" then return "[No Name]" end
                -- now, if the filename would occupy more than 1/4th of the available
                -- space, we trim the file path to its initials
                -- See Flexible Components section below for dynamic truncation
                if not conditions.width_percent_below(#filename, 0.25) then
                    filename = vim.fn.pathshorten(filename)
                end
                if vim.bo.modified then
                    filename = filename .. '*'
                end
                if not vim.bo.modifiable or vim.bo.readonly then
                    filename = filename .. ' '
                end
                return filename
            end,
            hl = { fg = "bright_blue" },
        }

        -- Now, let's say that we want the filename color to change if the buffer is
        -- modified. Of course, we could do that directly using the FileName.hl field,
        -- but we'll see how easy it is to alter existing components using a "modifier"
        -- component

        local FileNameModifer = {
            hl = function()
                if vim.bo.modified then
                    -- use `force` because we need to override the child's hl foreground
                    return { fg = "cyan", bold = true, force=true }
                end
            end,
        }

        -- let's add the children to our FileNameBlock component
        FileNameBlock = utils.insert(FileNameBlock,
            utils.insert(FileNameModifer, FileName), -- a new table where FileName is a child of FileNameModifier
            FileIcon,
            { provider = '%<'} -- this means that the statusline is cut here when there's not enough space
        )

        -- FileNameBlock = utils.surround({"█", "█"}, "bg_3", FileNameBlock)

        local FileType = {
            condition = function()
                return vim.bo.filetype ~= ''
            end,
            provider = function()
                return string.lower(vim.bo.filetype) .. " "
            end,
            hl = { fg = utils.get_highlight("Type").fg, bold = true },
        }

        local FileEncoding = {
            hl = { fg = "fg_2" },
            provider = function()
                local enc = (vim.bo.fenc ~= '' and vim.bo.fenc) or vim.o.enc -- :h 'enc'
                return enc:lower()
            end
        }

        local BufferInfo = {
            utils.surround({"█", "█"}, "bg_2", {FileType, FileEncoding})
        }

        local Diagnostics = {
            static = {
                error_icon = "󰅚",
                warn_icon = "󰀪",
                info_icon = "󰋽",
                hint_icon = "󰌶",
            },
            init = function(self)
                self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
                self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
                self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
                self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
            end,

            update = { "DiagnosticChanged", "BufEnter" },
            {
                provider = function(self)
                    return (self.error_icon .. self.errors .. " ")
                end,
                hl = { fg = "diag_error" },
            },
            {
                provider = function(self)
                    return (self.warn_icon .. self.warnings .. " ")
                end,
                hl = { fg = "diag_warn" },
            },
            --[[{
                provider = function(self)
                    return (self.info_icon .. self.info .. " ")
                end,
                hl = { fg = "diag_info" },
            },]]
            {
                provider = function(self)
                    return (self.hint_icon .. self.hints)
                end,
                hl = { fg = "diag_hint" },
            },
        }

        local LSPActive = {
            update = {'LspAttach', 'LspDetach'},

            -- You can keep it simple,
            -- provider = " [LSP]",

            -- Or complicate things a bit and get the servers names
            provider = function()
                local names = {}
                for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
                    table.insert(names, server.name)
                end
                return "[" .. table.concat(names, " ") .. "]"
            end,
            hl = { fg = "green", bold = true },
        }

        local LSPStatus = {
            condition = conditions.lsp_attached,
            LSPActive, Space, Diagnostics,
        }

        local Ruler = {
            hl = { fg = "bright_white" },
            provider = function ()
                local row = vim.api.nvim_win_get_cursor(0)[1] + 0.0
                local totalRows = vim.fn.line('$') + 0.0
                return
                    "%l:%c "
                    .. math.floor(row / totalRows * 100 + 0.5)
                    .. "%%"
            end
        }

        Ruler = utils.surround({"█", "█"}, "bg_1", Ruler)

        local MainRight = {
            --utils.surround({"",""}, "bg_2", ViMode),
            ViMode,
            Space,
            FileNameBlock,
        }

        local MainLeft = {
            BufferInfo,
            utils.surround({"",""}, "bg_2", Ruler)
        }

        local DefaultStatusLine = {
            hl = { bg = "bg_3" },
            MainRight, Space,
            Align,
            LSPStatus, Space, MainLeft
        }

        require("heirline").setup({
            statusline = DefaultStatusLine
        })
    end
}
