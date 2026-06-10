require('options')
vim.g.dotnet_errors_only = true
vim.g.dotnet_show_project_file = false
require('keymaps')
require("lazy.bootstrap")
require("lazy").setup(require("lazy.config"))
-- si estas usando un compilador primero :compiler <your-compiler> and :make
require('mappings')
