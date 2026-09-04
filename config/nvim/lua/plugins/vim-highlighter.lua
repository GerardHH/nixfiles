return {
	"azabiong/vim-highlighter",
	version = "*",
	lazy = true,
	keys = {
		{ "<leader>h+", "<CMD>Hi +<CR>", desc = "Highlight set" },
		{ "<leader>h-", "<CMD>Hi clear<CR>", desc = "Highlight clear" },
		{ "<leader>hN", "<CMD>Hi><CR>", desc = "Highlight jump next cursor" },
		{ "<leader>hP", "<CMD>Hi<<CR>", desc = "Highlight jump previous cursor" },
		{ "<leader>ha", "<CMD>Hi ==<CR>", desc = "Highlight all buffers" },
		{ "<leader>he", "<CMD>Hi -<CR>", desc = "Highlight erase" },
		{ "<leader>hn", "<CMD>Hi}<CR>", desc = "Highlight jump next any" },
		{ "<leader>hp", "<CMD>Hi{<CR>", desc = "Highlight jump previous any" },
		{ "<leader>hs", "<CMD>Hi =<CR>", desc = "Highlight single buffer" },
	},
}
