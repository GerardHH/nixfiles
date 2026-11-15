-- Init for the specs (see the Makefile): only agent-review and plenary.nvim
-- on the runtimepath, without lazy.nvim, so a run depends on nothing but
-- AGENT_REVIEW_DEPS. trouble.nvim isn't loaded: the specs test `collect`,
-- which both front ends build on.

local tests_directory = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local plugin_directory = vim.fs.dirname(tests_directory)
local deps_directory = vim.env.AGENT_REVIEW_DEPS ~= nil
        and vim.env.AGENT_REVIEW_DEPS ~= ""
        and vim.fs.normalize(vim.env.AGENT_REVIEW_DEPS)
    or plugin_directory .. "/.sandbox/deps"

-- Fail here rather than in every spec with an obscure require error.
local plenary_directory = deps_directory .. "/plenary.nvim"
if not vim.uv.fs_stat(plenary_directory) then
    error("Missing plenary.nvim in " .. deps_directory .. " (AGENT_REVIEW_DEPS, or make deps)")
end

vim.opt.runtimepath:prepend(plugin_directory)
vim.opt.runtimepath:append(plenary_directory)

-- Specs require("tests.helpers"), relative to the plugin directory.
package.path = plugin_directory .. "/?.lua;" .. package.path

-- nvim runs with --noplugin, so define :PlenaryBustedDirectory by hand.
vim.cmd.runtime("plugin/plenary.vim")
