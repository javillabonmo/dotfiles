-- DOCS:
-- https://neovim.io/doc/user/options.html
-- https://neovim.io/doc/user/vim_diff.html
--   [2] Defaults - *nvim-defaults*
local opt = vim.opt
local options = {
	number         = true,
	showmatch      = true,
	cursorline     = true,
	cursorlineopt  = "number",
	wrap		   = false,
	-----------------------------------------------------------
	-- Tabs, indent
	-----------------------------------------------------------
	splitright     = true,
	splitbelow     = true,
	relativenumber = true,
	undofile       = true,
	colorcolumn    = '120',
	synmaxcol      = 240,
	ignorecase     = true, -- All your searches will be case insensitive
	smartcase      = true, -- Your search will be case sensitive if it contains an uppercase letter
	swapfile       = false,
	termguicolors  = true,
	history        = 100,
	undolevels     = 100,

	-----------------------------------------------------------
	-- Tabs, indent
	-----------------------------------------------------------
	expandtab      = true, -- Use spaces instead of tabs
	shiftwidth     = 4, -- Shift 4 spaces when tab
	tabstop        = 4, -- 1 tab == 4 spaces
	smartindent    = true, -- Autoindent new lines
}
opt.shortmess:append "sI"
for k, v in pairs(options) do
	opt[k] = v
end
