local map = vim.keymap.set
local opts = { noremap = true, silent = true }

map('n', '<leader>qo', '<cmd>copen<CR>', vim.tbl_extend('force', opts, { desc = 'Open quickfix' }))
map('n', '<leader>qc', '<cmd>cclose<CR>', vim.tbl_extend('force', opts, { desc = 'Close quickfix' }))
map(
    "n",
    "<leader>ds",
    "<cmd>lua require('telescope.builtin').diagnostics({ bufnr = 0 })<CR>",
    opts, { desc = 'Buffer diagnostics' }
)
