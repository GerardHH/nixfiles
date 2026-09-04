local test = {}
return {
	"saghen/blink.cmp",
	version = "*",
	dependencies = {
		"rafamadriz/friendly-snippets",
	},
	lazy = true,
	event = "InsertEnter",
	keys = { ":", "/" },
	opts = {
		cmdline = {
			completion = {
				ghost_text = {
					enabled = true,
				},
				list = {
					selection = {
						preselect = false,
						auto_insert = true,
					},
				},
				menu = {
					auto_show = true,
				},
			},
			keymap = {
				preset = "inherit",
			},
		},
		completion = {
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 0,
			},
			ghost_text = {
				enabled = true,
				show_with_menu = true,
			},
			list = {
				selection = {
					preselect = false,
					auto_insert = true,
				},
			},
			menu = {
				auto_show = true,
				draw = {
					columns = {
						{ "label", "label_description", gap = 1 },
						{ "kind_icon", "kind" },
					},
				},
			},
		},
		keymap = {
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-u"] = { "scroll_documentation_up", "fallback" },
			["<C-d"] = { "scroll_documentation_down", "fallback" },
			["<Tab>"] = {
				function(cmp)
					if cmp.snippet_active() then
						return cmp.accept()
					else
						return cmp.select_and_accept()
					end
				end,
				"snippet_forward",
				"fallback",
			},
			["<S-Tab>"] = { "snippet_backward", "fallback" },
		},
	},
}
