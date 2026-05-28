local utils = {
	parsers = {
		"lua",
		"vim",
		"vimdoc",
		"css",
		"scss",
		"html",
		"javascript",
		"typescript",
		"c_sharp"
	},
	lsp_servers = {
		"lua_ls",
		"vimls",
		"html",
		"cssls",
		"jsonls",
	},
	-- roslyn lo maneja roslyn.nvim, no lspconfig/mason-lspconfig
	formatters = {
		"stylua",
		"xmlformatter",
		"csharpier",
	},
}

return utils
