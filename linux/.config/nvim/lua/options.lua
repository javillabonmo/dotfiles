-- DOCS:
-- https://neovim.io/doc/user/options.html
-- https://neovim.io/doc/user/vim_diff.html
--   [2] Defaults - *nvim-defaults*
local opt = vim.opt
local options = {
	-----------------------------------------------------------
	-- UI
	-----------------------------------------------------------
	number         = true,
	relativenumber = true,
	cursorline     = true,
	cursorlineopt  = "number",
	showmatch      = true,
	wrap           = false,
	colorcolumn    = '120',
	synmaxcol      = 240,
	termguicolors  = true,

	-----------------------------------------------------------
	-- Behavior
	-----------------------------------------------------------
	splitright     = true,
	splitbelow     = true,
	undofile       = true,
	swapfile       = false,
	history        = 100,
	undolevels     = 100,
	ignorecase     = true,
	smartcase      = true,

	-----------------------------------------------------------
	-- Tabs, indent
	-----------------------------------------------------------
	expandtab      = true,
	shiftwidth     = 4,
	tabstop        = 4,
	smartindent    = true,
}
opt.shortmess:append "sI"
for k, v in pairs(options) do
	opt[k] = v
end
