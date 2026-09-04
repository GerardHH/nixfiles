local augroup = vim.api.nvim_create_augroup
local group = augroup("user", {})

local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked symbols
autocmd({ "TextYankPost" }, {
	group = group,
	pattern = "*",
	callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 300 }) end,
})

-- Keep cursor in the middle of the screen
autocmd({ "BufEnter", "WinEnter", "WinNew", "VimResized" }, {
	group = group,
	pattern = "*",
	command = "let &scrolloff=(winheight(win_getid())/2) + 1",
})
