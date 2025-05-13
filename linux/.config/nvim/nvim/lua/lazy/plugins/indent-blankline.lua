local opts = {
	indent = {
		char = "▏",
		tab_char = "▏",
		smart_indent_cap = true,
	},
	exclude = {
		filetypes = {
			"help",
			"lazy",
		},
	},
	scope = { enabled = false },
}
local plugin = {
	"lukas-reineke/indent-blankline.nvim",
	opts = opts,
	main = "ibl",
}

return plugin
