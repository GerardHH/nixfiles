return {
	enabled = false, -- breaks log file highlighting
	"LunarVim/bigfile.nvim",
	version = "*",
	lazy = true,
	event = "BufReadPre",
	opts = {
		filesize = 2, -- size of the file in MiB, the plugin round file sizes to the closest MiB
	},
}
