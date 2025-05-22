local config = {
	spec = {
		-- import your plugins
		{ import = "lazy.plugins" },
	},
	ui = {
		border = "rounded",
		icons = {
			cmd = " ",
			config = "",
			event = "󱐋",
			ft = " ",
			init = " ",
			import = " ",
			keys = " ",
			lazy = "󰅒 ",
			loaded = "󰦛 ",
			not_loaded = "󱄍 ",
			plugin = " ",
			runtime = " ",
			require = "󰢱 ",
			source = " ",
			start = "󰠠",
			task = "",
			list = {
				"●",
				"➜",
				"󱕦",
				"‒",
			},
		}
	},
	checker = { enabled = true },
	change_detection = {
		notify = false,
	}
}

return config
