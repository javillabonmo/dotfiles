local plugin = {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
}
function plugin.config()
	require("nvim-treesitter.configs").setup {
		ensure_installed = require("utils").parsers,
		highlight = {
			enable = true,
			disable = function(lang, buf)
				local max_filesize = 100 * 1024 -- 100 KB
				local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
				if ok and stats and stats.size > max_filesize then
					return true
				end
			end,
			additional_vim_regex_highlighting = false,
		},
	}
end

return plugin
