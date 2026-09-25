local languages = require("languages")

return {
	{
		"nvim-treesitter/nvim-treesitter",
		version = "*",
		lazy = true,
		event = "VeryLazy",
		opts = {
			highlight = { enable = true },
			indent = { enable = true },
			-- Parsers come from nix, via home/modules/nvim.nix.
			auto_install = false,
			ensure_installed = {},
		},
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)

			local missing = {}

			for _, grammar in ipairs(languages.grammars) do
				if #vim.api.nvim_get_runtime_file("parser/" .. grammar .. ".so", false) == 0 then
					table.insert(missing, grammar)
				end
			end

			if #missing > 0 then
				table.sort(missing)
				vim.schedule(
					function()
						vim.notify(
							"Parsers missing from the nix runtime:\n" .. table.concat(missing, "\n"),
							vim.log.levels.WARN,
							{ title = "Treesitter" }
						)
					end
				)
			end
		end,
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		version = "*",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		lazy = true,
		event = "VeryLazy",
		opts = {
			indent = {
				char = "",
				highlight = {
					"RainbowRed",
					"RainbowYellow",
					"RainbowBlue",
					"RainbowOrange",
					"RainbowGreen",
					"RainbowViolet",
					"RainbowCyan",
				},
			},
		},
	},
	{
		"https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
		version = "*",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		lazy = true,
		keys = {
			{ "af", mode = { "v", "o" }, desc = "Around function" },
			{ "if", mode = { "v", "o" }, desc = "Inside function" },
			{ "ac", mode = { "v", "o" }, desc = "Around class" },
			{ "ic", mode = { "v", "o" }, desc = "Inside class" },
			{ "ai", mode = { "v", "o" }, desc = "Around conditional (if)" },
			{ "ii", mode = { "v", "o" }, desc = "Inside conditional (if)" },
			{ "al", mode = { "v", "o" }, desc = "Around loop" },
			{ "il", mode = { "v", "o" }, desc = "Inside loop" },
			{ "at", mode = { "v", "o" }, desc = "Select comment (text)" },
			{ "ap", mode = { "v", "o" }, desc = "Around parameter" },
			{ "ip", mode = { "v", "o" }, desc = "Inside parameter" },
			{ "ar", mode = { "v", "o" }, desc = "Around return" },
			{ "ir", mode = { "v", "o" }, desc = "Inside return" },
		},
		opts = {
			textobjects = {
				select = {
					enable = true,
					lookahead = true, -- Jump forward to textobj
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
						["ai"] = "@conditional.outer",
						["ii"] = "@conditional.inner",
						["al"] = "@loop.outer",
						["il"] = "@loop.inner",
						["at"] = "@comment.outer",
						["ap"] = "@parameter.outer",
						["ip"] = "@parameter.inner",
						["ar"] = "@return.outer",
						["ir"] = "@return.inner",
					},
				},
			},
		},
		config = function(_, opts) require("nvim-treesitter.configs").setup(opts) end,
	},
}
