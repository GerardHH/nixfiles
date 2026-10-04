-- Language support declared by home/modules/languages, read from the manifest
-- that home/modules/nvim.nix generates into $NVIM_NIX_RUNTIME. `dofile` rather
-- than `require` because plugin specs are collected before that directory is on
-- the runtimepath.

-- Without the manifest, nvim starts without language support instead of from a
-- hand-kept copy of the lists in home/modules/languages: Home Manager is the only
-- supported setup.
local function without_manifest(reason)
    vim.schedule(
        function()
            vim.notify(
                reason .. "\nStarting without language servers, grammars or format on save.",
                vim.log.levels.WARN,
                { title = "Languages" }
            )
        end
    )
    return { filetypes = {}, formatters = {}, grammars = {}, servers = {} }
end

local runtime = vim.env.NVIM_NIX_RUNTIME
if not runtime then return without_manifest("$NVIM_NIX_RUNTIME is not set: not started from a Home Manager shell?") end

local ok, manifest = pcall(dofile, runtime .. "/lua/nix_languages.lua")
if not ok or type(manifest) ~= "table" then
    return without_manifest("Could not read the nix language manifest in " .. runtime .. ".")
end

return manifest
