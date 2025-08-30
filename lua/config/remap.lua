vim.g.mapleader = " "

vim.keymap.set("n", "<leader>pv", function()
    vim.cmd("tab new")
    vim.cmd.Explore()
end, { desc = "Open file explorer in new tab" })
vim.keymap.set("n", "<leader>pV", vim.cmd.Explore, { desc = "Open file explorer" })

--move line
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

--better jumping
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("n", "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<Nop>")

vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format()
end, { desc = "Format buffer" })

--quick toggle (s)hell
local dir_utils = require("director.utils")
vim.keymap.set({"n", "t"}, "<C-s>", dir_utils.toggleTerminal, { desc = "Toggle terminal" })
vim.keymap.set({"n"}, "<leader><C-s>", function()
    dir_utils.openTerminal()
    local win = vim.api.nvim_get_current_win()
    vim.cmd("tab split")
    vim.api.nvim_win_close(win, true)
end, { desc = "Open terminal in new tab"})
vim.keymap.set({"n", "t"}, "<leader><leader><C-s>", dir_utils.forceKillTerminal, { desc = "Kill terminal" })

--tab navigation
vim.keymap.set("n", "<leader>t", [[<cmd>tab split<CR>]], { desc = "Duplicate buffer in new tab" })
vim.keymap.set("n", "H", [[gT]], { desc = "Tab left" })
vim.keymap.set("n", "L", [[gt]], { desc = "Tab right" })
