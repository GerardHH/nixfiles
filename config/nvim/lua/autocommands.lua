local augroup = vim.api.nvim_create_augroup
local group = augroup("user", {})

local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked symbols
autocmd({ "TextYankPost" }, {
	group = group,
	pattern = "*",
	callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 300 }) end,
})

-- Yank into primary clipboard
vim.api.nvim_create_autocmd("TextYankPost", {
	group = group,
	pattern = "*",
	callback = function()
		if vim.v.event.operator == "y" then vim.fn.setreg("*", vim.v.event.regcontents, vim.v.event.regtype) end
	end,
})

-- Keep cursor in the middle of the screen
autocmd({ "BufEnter", "WinEnter", "WinNew", "VimResized" }, {
	group = group,
	pattern = "*",
	command = "let &scrolloff=(winheight(win_getid())/2) + 1",
})
