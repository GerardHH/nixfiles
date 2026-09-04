return {
	"folke/todo-comments.nvim",
	version = "*",
	dependencies = { "nvim-lua/plenary.nvim" },
	lazy = false,
	keys = {
		{ "<leader>vt", "<CMD>TodoQuickFix<CR>", desc = "View todo-comments" },
	},
	opts = {
		highlight = {
			pattern = [[.*<(KEYWORDS)\s*]], -- vim regex
		},
		search = {
			pattern = [[\b(KEYWORDS)\b]],
		},
	},
}
