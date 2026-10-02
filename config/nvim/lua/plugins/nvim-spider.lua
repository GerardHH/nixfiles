return {
	"chrisgrieser/nvim-spider",
	lazy = true,
	keys = {
		{ "w", "<CMD>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" }, desc = "Spider-w" },
		{ "e", "<CMD>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" }, desc = "Spider-e" },
		{ "b", "<CMD>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" }, desc = "Spider-b" },
	},
	opts = {
		skipInsignificantPunctuation = false, -- Don't skip to over to white space surrounded words
	},
}
