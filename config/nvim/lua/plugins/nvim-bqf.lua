return {
	"kevinhwang91/nvim-bqf",
	version = "*",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	lazy = true,
	ft = "qf",
	keys = {
		{
			"<leader>Cq",
			function()
				for _, win in pairs(vim.fn.getwininfo()) do
					if win["quickfix"] == 1 then
						vim.cmd("cclose")
						return
					end
				end
				vim.cmd("copen")
			end,
			desc = "Qf toggle",
		},
		{
			"<leader>Cd",
			function() vim.diagnostic.setqflist() end,
			desc = "Qf fill with diagnostics",
		},
	},
	opts = {},
}
