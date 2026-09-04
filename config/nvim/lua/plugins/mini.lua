return {
	{
		"echasnovski/mini.bufremove",
		version = "*",
		lazy = true,
		keys = {
			{ "<leader>q", function() require("mini.bufremove").delete(0) end, desc = "Quit buffer (mini.bufremove)" },
		},
	},
	{
		"echasnovski/mini.files",
		version = "*",
		lazy = true,
		keys = {
			{
				"<leader>ve",
				function() require("mini.files").open(vim.api.nvim_buf_get_name(0), false) end,
				desc = "View explorer (mini.files)",
			},
		},
		opts = {
			mappings = {
				show_help = "<F1>",
			},
			windows = {
				preview = true,
				width_preview = 50,
			},
		},
	},
	{
		"echasnovski/mini.move",
		version = "*",
		lazy = true,
		keys = {
			{ "<M-h>", mode = { "n", "x" }, desc = "Indent line/selection left (mini.move)" },
			{ "<M-l>", mode = { "n", "x" }, desc = "Indent line/selection right (mini.move)" },
			{ "<M-j>", mode = { "n", "x" }, desc = "Move line/selection down (mini.move)" },
			{ "<M-k>", mode = { "n", "x" }, desc = "Move line/selection up (mini.move)" },
		},
		opts = {},
	},
	{
		"echasnovski/mini.operators",
		version = "*",
		lazy = true,
		keys = {
			{ "<leader>or", mode = { "v", "x" }, desc = "Replace with register (mini.operators)" },
			{ "<leader>os", mode = { "v", "x" }, desc = "Sort (mini.operators)" },
		},
		opts = {
			evaluate = {
				prefix = "",
			},
			exchange = {
				prefix = "",
			},
			multiply = {
				prefix = "",
			},
			replace = {
				prefix = "<leader>or",
			},
			sort = {
				prefix = "<leader>os",
			},
		},
	},
	{
		"echasnovski/mini.pairs",
		version = "*",
		lazy = true,
		keys = {
			{ "(", mode = "i", desc = "Auto close pair (mini.pairs)" },
			{ "[", mode = "i", desc = "Auto close pair (mini.pairs)" },
			{ "{", mode = "i", desc = "Auto close pair (mini.pairs)" },
			{ ")", mode = "i", desc = "Skip over if paired (mini.pairs)" },
			{ "]", mode = "i", desc = "Skip over if paired (mini.pairs)" },
			{ "}", mode = "i", desc = "Skip over if paired (mini.pairs)" },
			{ '"', mode = "i", desc = "Auto close pair & skip over if paired (mini.pairs)" },
			{ "'", mode = "i", desc = "Auto close pair & skip over if paired (mini.pairs)" },
			{ "`", mode = "i", desc = "Auto close pair & skip over if paired (mini.pairs)" },
		},
		opts = {},
	},
	{
		"echasnovski/mini.splitjoin",
		version = "*",
		lazy = true,
		keys = {
			{ "<leader>~", desc = "Split/Join arguments (mini.splitjoin)" },
		},
		opts = {
			mappings = {
				toggle = "<leader>~",
			},
		},
	},
	{
		"echasnovski/mini.trailspace",
		main = "mini.trailspace",
		version = "*",
		lazy = true,
		event = { "BufReadPre", "BufNewFile" },
		opts = {},
		config = function(pkg, opts)
			require(pkg.main).setup(opts)

			local group = vim.api.nvim_create_augroup(pkg.main, {})
			vim.api.nvim_create_autocmd({ "BufWritePre" }, {
				group = group,
				pattern = "*",
				callback = function() require(pkg.main).trim() end,
			})
		end,
	},
}
