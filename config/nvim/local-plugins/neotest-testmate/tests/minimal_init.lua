-- Init for the specs (see the Makefile): only the adapter under test, its
-- dependencies and a C++ parser on the runtimepath, without lazy.nvim, so a
-- run depends on nothing but the TESTMATE_* variables.

local tests = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

local function path(name, default)
    local value = vim.env[name]
    if value and value ~= "" then return vim.fs.normalize(value) end
    return default
end

local plugin = path("TESTMATE_PLUGIN", vim.fs.dirname(tests))
local deps = path("TESTMATE_DEPS", vim.fs.dirname(tests) .. "/.sandbox/deps")
local parsers = path("TESTMATE_PARSERS", vim.env.NVIM_NIX_RUNTIME)

-- Fail here rather than in every spec with an obscure require error.
local function check(dir, what)
    if not vim.uv.fs_stat(dir) then error(("Missing %s: %s"):format(what, dir)) end
end

check(plugin .. "/lua/neotest-testmate/init.lua", "adapter under test (TESTMATE_PLUGIN)")
vim.opt.runtimepath:prepend(plugin)
-- nvim-dap for tests/integration/debug_spec.lua.
for _, name in ipairs({ "plenary.nvim", "nvim-nio", "neotest", "neotest-ctest", "nvim-dap" }) do
    check(deps .. "/" .. name, "dependency (TESTMATE_DEPS, or make deps)")
    vim.opt.runtimepath:append(deps .. "/" .. name)
end
if parsers then vim.opt.runtimepath:append(parsers) end
if #vim.api.nvim_get_runtime_file("parser/cpp.so", false) == 0 then
    error("No C++ tree-sitter parser: set TESTMATE_PARSERS to a directory with parser/cpp.so")
end

-- Specs require("tests.helpers"), relative to the directory make runs in.
package.path = vim.fs.dirname(tests) .. "/?.lua;" .. package.path

-- nvim runs with --noplugin, so define :PlenaryBustedDirectory by hand.
vim.cmd.runtime("plugin/plenary.vim")
