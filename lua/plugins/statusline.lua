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
            return {
                bg_1 = utils.get_highlight("StatusLine").bg,
                bg_2 = utils.get_highlight("ColorColumn").bg,
                fg_1 = utils.get_highlight("StatusLine").fg,
                fg_2 = utils.get_highlight("Normal").fg,

                black = vim.g["terminal_color_0"],
                red = vim.g["terminal_color_1"],
                green = vim.g["terminal_color_2"],
                yellow = vim.g["terminal_color_3"],
                blue = vim.g["terminal_color_4"],
                magenta = vim.g["terminal_color_5"],
                cyan = vim.g["terminal_color_6"],
                white = vim.g["terminal_color_7"],
                bright_black = vim.g["terminal_color_8"],
                bright_red = vim.g["terminal_color_9"],
                bright_green = vim.g["terminal_color_10"],
                bright_yellow = vim.g["terminal_color_11"],
                bright_blue = vim.g["terminal_color_12"],
                bright_magenta = vim.g["terminal_color_13"],
                bright_cyan = vim.g["terminal_color_14"],
                bright_white = vim.g["terminal_color_15"],

                diag_warn = utils.get_highlight("DiagnosticWarn").fg,
                diag_error = utils.get_highlight("DiagnosticError").fg,
                diag_hint = utils.get_highlight("DiagnosticHint").fg,
                diag_info = utils.get_highlight("DiagnosticInfo").fg,
                git_del = utils.get_highlight("diffDeleted").fg,
                git_add = utils.get_highlight("diffAdded").fg,
                git_change = utils.get_highlight("diffChanged").fg,
            }
        end
        require("heirline").load_colors(setup_colors())

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
            static = {
                mode_names = {
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
                    ["\22"] = "V-Blck",
                    ["\22s"] = "V-Blck",
                    ["s"] = "Select",
                    ["S"] = "S-Line",
                    ["\19"] = "S-Blck",
                    ["i"] = "Insert",
                    ["ic"] = "Insert",
                    ["ix"] = "Insert",
                    ["R"] = "Replce",
                    ["Rc"] = "Replce",
                    ["Rx"] = "Replce",
                    ["Rv"] = "V-Rplc",
                    ["Rvc"] = "V-Rplc",
                    ["Rvx"] = "V-Rplc",
                    ["c"] = "Commnd",
                    ["cv"] = "Ex    ",
                    ["ce"] = "Ex    ",
                    ["r"] = "Replce",
                    ["rm"] = "More  ",
                    ["r?"] = "Confrm",
                    ["!"] = "Shell ",
                    ["t"] = "Termnl",
                },
            },
            provider = function(self)
                return "%2("..self.mode_names[self.mode()].."%)"
            end,
            -- Same goes for the highlight. Now the foreground will change according to the current mode.
            hl = function(self)
                return { fg = "bg_2", bg = self:mode_color(), bold = true, }
            end,
            update = {
                "ModeChanged",
                pattern = "*:*",
                callback = vim.schedule_wrap(function()
                    vim.cmd("redrawstatus")
                end),
            },
        }
        ViMode = utils.surround({"█", "█"}, function(self) return self:mode_color() end, ViMode)

        local FileNameBlock = {
            init = function(self)
                if vim.bo.buftype == "terminal" then
                    self.filename = "[No Name]"
                else
                    self.filename = vim.api.nvim_buf_get_name(0)
                end
            end,
        }

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
                local filename = vim.fn.fnamemodify(self.filename, ":.")
                if filename == "" then return "[No Name]" end
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

        local FileNameModifer = {
            hl = function()
                if vim.bo.modified then
                    -- use `force` because we need to override the child's hl foreground
                    return { fg = "cyan", bold = true, force=true }
                end
            end,
        }

        FileNameBlock = utils.insert(FileNameBlock,
            utils.insert(FileNameModifer, FileName), -- a new table where FileName is a child of FileNameModifier
            FileIcon,
            { provider = '%<'} -- this means that the statusline is cut here when there's not enough space
        )

        local FileType = {
            condition = function()
                return vim.bo.filetype ~= ''
            end,
            provider = function()
                return string.lower(vim.bo.filetype) .. " "
            end,
            hl = { fg = "fg_1", bold = true },
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
            {
                provider = function(self)
                    return (self.info_icon .. self.info .. " ")
                end,
                hl = { fg = "diag_info" },
            },
            {
                provider = function(self)
                    return (self.hint_icon .. self.hints)
                end,
                hl = { fg = "diag_hint" },
            },
        }

        local LSPActive = {
            update = {'LspAttach', 'LspDetach'},

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
            hl = { fg = "bg_2" },
            provider = function ()
                local row = vim.api.nvim_win_get_cursor(0)[1] + 0.0
                local totalRows = vim.fn.line('$') + 0.0
                return
                    "%l:%c "
                    .. math.floor(row / totalRows * 100 + 0.5)
                    .. "%%"
            end
        }

        Ruler = utils.surround({"█", "█"}, function(self) return self:mode_color() end, Ruler)

        local MainLeft = {
            ViMode,
            Space,
            FileNameBlock,
        }

        local MainRight = {
            BufferInfo,
            utils.surround({"",""}, "bg_2", Ruler)
        }

        local DefaultStatusLine = {
            hl = { bg = "bg_1" },
            MainLeft, Space,
            Align,
            LSPStatus, Space, MainRight,
            static = {
                mode_color_map = {
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
                },
                mode = function()
                    local mode = conditions.is_active() and vim.fn.mode() or "n"
                    mode = mode:sub(1, 1)
                    return mode
                end,
                mode_color = function(self)
                    return self.mode_color_map[self.mode()]
                end
            }
        }

        local Tabpage = {
            provider = function(self)
                local buf = vim.api.nvim_win_get_buf(
                    vim.api.nvim_tabpage_get_win(self.tabpage)
                )

                local bufname = vim.api.nvim_buf_get_name(buf)
                local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
                local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })

                print("bufname: "..bufname)
                print("buftype: "..buftype)
                print("filetype: "..filetype)

                if buftype == "terminal" then
                    return " [Terminal] "
                end

                if filetype == "netrw" then
                    return " netrw "
                end

                if bufname == "" then
                    if filetype == "" then
                        return " [No Name] "
                    else
                        return " "..filetype.." "
                    end
                end

                return " "..vim.fn.fnamemodify(bufname, ":t").." "
            end,
            hl = function(self)
                if not self.is_active then
                    return "TabLine"
                else
                    return "TabLineSel"
                end
            end,
        }

        require("heirline").setup({
            statusline = DefaultStatusLine,
            tabline = utils.make_tablist(Tabpage),
        })
    end
}
