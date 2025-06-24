local util = require("config.utils")

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Explore)

--move line
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

--better jumping
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("n", "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<Nop>")

vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format()
end)

--vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>"]])

--insert mode movement
vim.keymap.set({"i", "s"}, [[<C-h>]], [[<Left>]])
vim.keymap.set({"i", "s"}, [[<C-j>]], [[<Down>]])
vim.keymap.set({"i", "s"}, [[<C-k>]], [[<Up>]])
vim.keymap.set({"i", "s"}, [[<C-l>]], [[<Right>]])

--surround word with bracket/quote/etc
vim.keymap.set("n", [[<leader>(]], [[Bi(<Esc>viW<Esc>a)<Esc>]])
vim.keymap.set("n", [[<leader>[]], [[Bi[<Esc>viW<Esc>a]<Esc>]])
vim.keymap.set("n", [[<leader>{]], [[Bi{<Esc>viW<Esc>a}<Esc>]])
vim.keymap.set("n", [[<leader>"]], [[Bi"<Esc>viW<Esc>a"<Esc>]])
vim.keymap.set("n", [[<leader>']], [[Bi'<Esc>viW<Esc>a'<Esc>]])
vim.keymap.set("n", [[<leader><]], [[Bi<<Esc>viW<Esc>a><Esc>]])

--quick toggle shell
vim.keymap.set({"n", "t"}, "<C-s>", function()
    util.toggleTerminal()
end)

--tab navigation
vim.keymap.set("n", "<leader>t", [[<cmd>tab split<CR>]])
vim.keymap.set("n", "H", [[gT]])
vim.keymap.set("n", "L", [[gt]])

--Go to definition/declaration
vim.keymap.set(
    "n",
    "gd",
    function()
        vim.cmd("tab split")
        vim.lsp.buf.definition()
    end,
    { noremap = true, silent = true }
)
vim.keymap.set(
    "n",
    "gD",
    function()
        vim.cmd("tab split")
        vim.lsp.buf.declaration()
    end,
    { noremap = true, silent = true }
)

--diagnostic navigation
vim.keymap.set(
    "n",
    "<leader>de",
    function()
        util.gotoFirstDiagnostic(0, vim.diagnostic.severity.ERROR)
    end
)

vim.keymap.set(
    "n",
    "<leader>dw",
    function()
        util.gotoFirstDiagnostic(0, vim.diagnostic.severity.WARN)
    end
)

vim.keymap.set(
    "n",
    "<leader>dh",
    function()
        util.gotoFirstDiagnostic(0, vim.diagnostic.severity.HINT)
    end
)

--buildsystem menu
local bs = require("config.director")
vim.keymap.set(
    "n",
    "<leader>b",
    bs.actionsMenu
)
