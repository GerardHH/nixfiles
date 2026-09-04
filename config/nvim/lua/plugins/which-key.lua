return {
	"folke/which-key.nvim",
	main = "which-key",
	version = "*",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 1000
	end,
	lazy = true,
	keys = "<leader>",
	opts = {
		spec = {
			{ "<leader>C", group = "Quickfix", mode = { "n", "o", "v", "x" } },
			{
				"<leader>S",
				group = "Split",
				mode = { "n", "o", "v", "x" },
				expand = function() return require("which-key.extras").expand.win() end,
			},
			{
				"<leader>b",
				group = "Buffer",
				mode = { "n", "o", "v", "x" },
				expand = function() return require("which-key.extras").expand.buf() end,
			},
			{ "<leader>d", group = "Debug", mode = { "n", "o", "v", "x" } },
			{ "<leader>f", group = "FZF", mode = { "n", "o", "v", "x" } },
			{ "<leader>g", group = "Git", mode = { "n", "o", "v", "x" } },
			{ "<leader>gc", group = "Git Conflict", mode = { "n", "o", "v", "x" } },
			{ "<leader>gh", group = "Git Hunk", mode = { "n", "o", "v", "x" } },
			{ "<leader>gt", group = "Git Toggle", mode = { "n", "o", "v", "x" } },
			{ "<leader>h", group = "Highlight", mode = { "n", "o", "v", "x" } },
			{ "<leader>l", group = "LSP", mode = { "n", "o", "v", "x" } },
			{ "<leader>ld", group = "LSP Diagnostic", mode = { "n", "o", "v", "x" } },
			{ "<leader>lg", group = "LSP Go to", mode = { "n", "o", "v", "x" } },
			{ "<leader>lp", group = "LSP Peek", mode = { "n", "o", "v", "x" } },
			{ "<leader>m", group = "Bookmark", mode = { "n", "o", "v", "x" } },
			{ "<leader>n", group = "Noice", mode = { "n", "o", "v", "x" } },
			{ "<leader>o", group = "Operator", mode = { "n", "o", "v", "x" } },
			{ "<leader>r", group = "Run", mode = { "n", "o", "v", "x" } },
			{ "<leader>t", group = "Test", mode = { "n", "o", "v", "x" } },
			{ "<leader>v", group = "View", mode = { "n", "o", "v", "x" } },
			{ "<leader>vs", group = "View Split", mode = { "n", "o", "v", "x" } },
		},
	},
}
