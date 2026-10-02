return {
	"nguyenvukhang/nvim-toggler",
	lazy = true,
	keys = {
		{
			"<leader>i",
			mode = { "n", "v" },
			function() require("nvim-toggler").toggle() end,
			desc = "Invert text",
		},
	},
	opts = {
		remove_default_keybinds = true,
	},
}
