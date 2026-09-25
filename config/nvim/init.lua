require("autocommands")
require("keymaps")
require("options")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Parsers and the generated language manifest, built by home/modules/nvim.nix.
-- Absent when this config is used outside Home Manager.
local nix_runtime = vim.env.NVIM_NIX_RUNTIME

require("lazy").setup("plugins", {
	checker = {
		enabled = true,
		notify = false,
	},
	change_detection = {
		enabled = true,
		notify = false,
	},
	performance = {
		rtp = {
			paths = nix_runtime and { nix_runtime } or {},
		},
	},
})
