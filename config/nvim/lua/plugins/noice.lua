return {
	"folke/noice.nvim",
	version = "*",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
	lazy = false,
	keys = {
		{ "<leader>n", "<CMD>Noice last<CR>", desc = "Noice last notification" },
		{ "<leader>N", "<CMD>Noice history<CR>", desc = "Noice history" },
	},
	opts = {
		lsp = {
			-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
			},
		},
		presets = {
			inc_rename = true,
			lsp_doc_border = true, -- add a border to hover docs and signature help
		},
	},
}
