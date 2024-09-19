vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

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

--vim.keymap.set("n", "<C-s>", ":w<CR>")

--auto surround commands
vim.keymap.set("n", [[<leader>(]], [[Bi(<Esc>viW<Esc>a)<Esc>]])
vim.keymap.set("n", [[<leader>[]], [[Bi[<Esc>viW<Esc>a]<Esc>]])
vim.keymap.set("n", [[<leader>{]], [[Bi{<Esc>viW<Esc>a}<Esc>]])
vim.keymap.set("n", [[<leader>"]], [[Bi"<Esc>viW<Esc>a"<Esc>]])
vim.keymap.set("n", [[<leader>']], [[Bi'<Esc>viW<Esc>a'<Esc>]])
vim.keymap.set("n", [[<leader><]], [[Bi<<Esc>viW<Esc>a><Esc>]])

--quick toggle shell
vim.keymap.set("n", "<C-s>", [[:tab split<CR>:te<CR>A]])
vim.keymap.set("t", "<C-s>", [[<C-\><C-n>:q<CR>]])
