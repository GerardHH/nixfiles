-- Language support declared by home/modules/languages, read from the manifest
-- that home/modules/nvim.nix generates into $NVIM_NIX_RUNTIME. `dofile` rather
-- than `require` because plugin specs are collected before that directory is on
-- the runtimepath.
local fallback = {
	filetypes = {
		"bash",
		"c",
		"cmake",
		"cpp",
		"lua",
		"markdown",
		"nix",
		"python",
		"sh",
	},
	grammars = {},
	servers = {
		"bashls",
		"clangd",
		"cmake",
		"lua_ls",
		"marksman",
		"nixd",
		"pyright",
		"ruff",
	},
}

local runtime = vim.env.NVIM_NIX_RUNTIME
if not runtime then return fallback end

local ok, manifest = pcall(dofile, runtime .. "/lua/nix_languages.lua")
if not ok or type(manifest) ~= "table" then
	vim.schedule(
		function()
			vim.notify(
				"Could not read the nix language manifest; using the built-in list.",
				vim.log.levels.WARN,
				{ title = "Languages" }
			)
		end
	)
	return fallback
end

return manifest
