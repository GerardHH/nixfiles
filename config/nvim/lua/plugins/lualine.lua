return {
	"nvim-lualine/lualine.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	lazy = false,
	config = function()
		local lualine = require("lualine")
		local lazy_status = require("lazy.status")

		local function yazi_shell()
			local yazi_level = os.getenv("YAZI_LEVEL")
			if yazi_level ~= nil then return string.format(" Yazi %d", yazi_level) end
			return ""
		end

		local palette = require("catppuccin.palettes.mocha")
		local panels = {
			filetypes = {
				"dap-repl",
				"dapui_breakpoints",
				"dapui_console",
				"dapui_scopes",
				"dapui_stacks",
				"dapui_watches",
				"neotest-output-panel",
				"neotest-summary",
			},
			sections = {
				lualine_c = { { "filename", file_status = false, color = { fg = palette.sky } } },
			},
			inactive_sections = {
				lualine_c = { { "filename", file_status = false } },
			},
		}

		lualine.setup({
			options = {
				theme = "auto",
			},
			sections = {
				lualine_x = {
					{
						yazi_shell,
						color = { fg = palette.blue },
					},
					{
						lazy_status.updates,
						cond = lazy_status.has_updates,
						color = { fg = "#ff9e64" },
					},
					{ "encoding" },
					{ "fileformat" },
					{ "filetype" },
				},
			},
			extensions = { panels },
		})
	end,
}
