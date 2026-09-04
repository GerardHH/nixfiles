return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		version = "*",
		dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
		lazy = true,
		ft = "markdown",
		opts = {},
	},
	{
		"Kicamon/markdown-table-mode.nvim",
		version = "*",
		lazy = true,
		cmd = "Mtm",
		opts = {
			options = {
				pad_separator_line = true, -- add space in separator line
			},
		},
	},
}
