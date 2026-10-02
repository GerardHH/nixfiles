return {
	"saghen/blink.cmp",
	dependencies = {
		"saghen/blink.lib",
		"rafamadriz/friendly-snippets",
	},
	-- cargo and rustc come from home/modules/nvim.nix, on PATH only for this build
	-- so they don't shadow a project's rustup toolchain.
	-- TODO: Once nix manages nvim plugins, take blink.cmp and blink.lib from nix
	-- (via `dir =`). The fuzzy matcher is then built in the derivation, and this
	-- hook and the toolchain in nvim.nix can go.
	build = function()
		local path = vim.env.PATH
		vim.env.PATH = vim.env.NVIM_NIX_RUNTIME .. "/bin:" .. path
		local ok, err = require("blink.cmp").build():pwait()
		vim.env.PATH = path
		if not ok then error(err) end
	end,
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
			["<C-u>"] = { "scroll_documentation_up", "fallback" },
			["<C-d>"] = { "scroll_documentation_down", "fallback" },
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
