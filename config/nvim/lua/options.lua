local opt = vim.opt -- for conciseness

opt.fileencoding = "utf-8" -- the encoding written to a file
opt.swapfile = false -- turn off swapfile

-- line numbers
opt.relativenumber = true -- show relative line numbers
opt.number = true -- shows absolute line number on cursor line (when relative number is on)
opt.cursorline = true -- highlight the current line

-- tabs & indentation
opt.tabstop = 4 -- 4 spaces for tabs (prettier default)
opt.shiftwidth = 4 -- 4 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive
opt.incsearch = true -- see what vim matches as it is typed
opt.hlsearch = true -- highlight all matches on previous search pattern

-- turn on termguicolors for nightfly colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- clipboard
opt.clipboard:append("unnamed,unnamedplus") -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- Spelling
opt.spell = true
opt.spelllang = { "en_us" }

-- Command line
opt.showmode = false -- we don't need to see things like -- INSERT -- anymore
opt.showcmd = false -- don't show command in the last line of the screen

-- Scrolling
opt.scrolloff = 8 -- minimal number of screen lines to keep above and below the cursor.
opt.sidescrolloff = 8 -- minimal number of screen lines to keep left and right of the cursor.

-- Diagnostics
vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.HINT] = "󰠠 ",
			[vim.diagnostic.severity.INFO] = " ",
		},
	},
	virtual_lines = {
		current_line = true,
	},
})
