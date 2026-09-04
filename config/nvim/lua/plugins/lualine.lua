return {
	"nvim-lualine/lualine.nvim",
	version = "*",
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

		lualine.setup({
			options = {
				theme = "auto",
			},
			sections = {
				lualine_x = {
					{
						yazi_shell,
						color = { fg = require("catppuccin.palettes.mocha").blue },
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
		})
	end,
}
