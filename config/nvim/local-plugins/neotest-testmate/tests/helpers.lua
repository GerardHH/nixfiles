-- Shared by the specs: fixture paths, running a spec's command, and reading
-- results by test name rather than by position id, whose format belongs to
-- the parser (neotest-ctest's for Catch2).
local lib = require("neotest.lib")
local nio = require("nio")

local helpers = {}

-- Built C++ projects, by name; for now nixfiles' dev-container-tests:
--   cmake-catch2   Catch2 v3, built on the host by CMake.
--   colcon-catch2  colcon workspace with GTest/GMock in src/toolbox/greeter,
--                  built in the container: its executables embed /workspaces
--                  paths, so the adapter can't find them on the host.
helpers.fixtures = vim.fs.normalize(vim.env.TESTMATE_FIXTURES or "tests/fixtures")

--- Absolute path of a file in the fixtures; errors when it is missing.
function helpers.fixture(relative)
    local path = vim.fs.joinpath(helpers.fixtures, relative)
    if not vim.uv.fs_stat(path) then error("Missing fixture (TESTMATE_FIXTURES): " .. path) end
    return path
end

--- Names of the test positions in a tree, in file order.
function helpers.test_names(tree)
    local names = {}
    for _, node in tree:iter_nodes() do
        if node:data().type == "test" then table.insert(names, node:data().name) end
    end
    return names
end

--- Status per test name, from results keyed by position id.
function helpers.statuses(tree, results)
    local statuses = {}
    for _, node in tree:iter_nodes() do
        local position = node:data()
        if position.type == "test" then
            statuses[position.name] = results[position.id] and results[position.id].status
        end
    end
    return statuses
end

--- Runs `spec.command` the way neotest's integrated strategy would, output
--- captured in a file, and returns the { code, output } that adapter.results
--- takes. Killed after `timeout` ms, so a hanging executable fails the spec.
function helpers.run_spec(spec, timeout)
    local done = nio.control.future()
    vim.system(spec.command, { cwd = spec.cwd, text = true, timeout = timeout or 30000 }, done.set)
    local result = done.wait()
    local output = nio.fn.tempname()
    lib.files.write(output, (result.stdout or "") .. (result.stderr or ""))
    return { code = result.code, output = output }
end

--- Last lines of neotest's log, for failure messages.
function helpers.log_tail(lines)
    local log = vim.fn.stdpath("log") .. "/neotest.log"
    if not vim.uv.fs_stat(log) then return "(no " .. log .. ")" end
    local content = vim.fn.readfile(log)
    return table.concat(vim.list_slice(content, math.max(1, #content - (lines or 40) + 1)), "\n")
end

return helpers
