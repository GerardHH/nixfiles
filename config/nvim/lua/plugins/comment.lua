return {
	"numToStr/Comment.nvim",
	main = "Comment",
	version = "*",
	dependencies = {
		"JoosepAlviste/nvim-ts-context-commentstring",
	},
	lazy = true,
	keys = {
		{ "<leader>c", "<Plug>(comment_toggle_linewise)", desc = "Comment linewise motion || Comment+" },
		{ "<leader>cB", "<Plug>(comment_toggle_blockwise_current)", desc = "Comment blockwise current" },
		{ "<leader>cb", "<Plug>(comment_toggle_blockwise)", desc = "Comment blockwise motion" },
		{ "<leader>cc", "<Plug>(comment_toggle_linewise_current)", desc = "Comment linewise current" },
		-- Visual
		{ "<leader>cb", "<Plug>(comment_toggle_blockwise_visual)", desc = "Comment blockwise", mode = "x" },
		{ "<leader>cc", "<Plug>(comment_toggle_linewise_visual)", desc = "Comment linewise", mode = "x" },
	},
	opts = {
		mappings = false,
	},
	config = function(pkg, opts)
		opts.pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
		require(pkg.main).setup(opts)
	end,
}
