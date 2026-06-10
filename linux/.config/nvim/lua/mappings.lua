local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map('n', '<leader>qo', '<cmd>copen<CR>', opts)
map('n', '<leader>qc', '<cmd>cclose<CR>', opts)
map(
    "n",
    "<leader>ds",
    "<cmd>lua require('telescope.builtin').diagnostics({ bufnr = 0 })<CR>",
    opts
)
