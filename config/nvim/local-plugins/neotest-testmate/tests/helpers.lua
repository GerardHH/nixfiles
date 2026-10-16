-- Shared by the specs: fixture paths, running a spec's command, running files
-- through neotest itself, and reading results by test name rather than by
-- position id, whose format belongs to the parser (neotest-ctest's for Catch2).
local lib = require("neotest.lib")
local nio = require("nio")

local helpers = {}

-- Built C++ projects in tests/fixtures, by name. They live here, not in
-- nixfiles' dev-container-tests, as only these specs use them; so FIXTURES
-- needs no setting. Build each in place before running the specs:
--   cmake-catch2  Catch2 v3, built on the host by CMake
--                 (`cmake --preset debug`, `cmake --build --preset debug`).
--   colcon        colcon workspace with Catch2 v2 in src/toolbox/calculator
--                 and text, and GTest/GMock in src/toolbox/greeter, next to a
--                 Catch2 test there that mocks with GMock. Built in its
--                 container (`colcon build`): its executables embed
--                 /workspaces paths, so the adapter can't find them on the
--                 host. The calculator and text packages have a test/main.cpp
--                 without test cases.
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

--- Sets up neotest with the adapter for the project in `root`, with a probe:
--- a consumer that records the client's events and discovered trees, so a
--- run that never finishes can say how far it got. Call it once per spec
--- file, outside `it`; each spec file runs in its own nvim.
function helpers.start_neotest(root)
    local probe = { events = {}, trees = {} }
    -- neotest takes the project from the working directory.
    vim.fn.chdir(root)
    os.remove(vim.fn.stdpath("log") .. "/neotest.log")
    require("neotest").setup({
        log_level = vim.log.levels.DEBUG,
        adapters = { require("neotest-testmate") },
        consumers = {
            probe = function(client)
                -- For helpers.run_suite, which needs the whole project's tree.
                probe.client = client
                for _, event in ipairs({ "starting", "started", "run" }) do
                    client.listeners[event] = function() table.insert(probe.events, event) end
                end
                client.listeners.discover_positions = function(_, tree)
                    table.insert(probe.events, "discover_positions")
                    -- Newest first, for helpers.run_file's lookup.
                    table.insert(probe.trees, 1, tree)
                end
                client.listeners.results = function(_, results, partial)
                    table.insert(probe.events, partial and "results (partial)" or "results")
                    -- Set by run_file and run_suite: they differ in how many
                    -- results events make a finished run.
                    if not partial and probe.on_results then probe.on_results(results) end
                end
                return {}
            end,
        },
    })
    return probe
end

-- Read once, here: after neotest.run.run, a spec may be in a fast event
-- context, where vim.env (getenv) is not allowed.
local timeout = tonumber(vim.env.TESTMATE_TIMEOUT) or 30000

--- Waits for `probe.finished`. Errors when it isn't set within
--- TESTMATE_TIMEOUT ms (default 30000, less than PLENARY_TEST_TIMEOUT so this
--- message wins), with the events seen and the end of neotest.log.
local function wait_for_results(probe)
    nio.first({ probe.finished.wait, function() nio.sleep(timeout) end })
    if not probe.finished.is_set() then
        error(
            ("No results after %d ms. Client events: %s\nEnd of neotest.log:\n%s"):format(
                timeout,
                #probe.events > 0 and table.concat(probe.events, ", ") or "none",
                helpers.log_tail()
            )
        )
    end
end

--- Runs `file` through neotest, as <leader>tf does, and returns the file's
--- tree and the run's results by position id. Errors when no results come
--- in time (see wait_for_results).
function helpers.run_file(probe, file)
    probe.finished = nio.control.event()
    probe.on_results = function(results)
        probe.results = results
        probe.finished.set()
    end
    nio.api.nvim_command("edit " .. vim.fn.fnameescape(file))
    require("neotest").run.run(file)

    wait_for_results(probe)
    for _, tree in ipairs(probe.trees) do
        local node = tree:get_key(file)
        if node then return node, probe.results end
    end
    error("Results came, but no discovery of " .. file)
end

--- Runs the whole project through neotest, as <leader>tp does, and returns
--- the project's tree and the results by position id. neotest runs a suite
--- file by file, each with its own results event, so they are merged until
--- every one of `files` has a result; errors when that takes too long (see
--- wait_for_results).
function helpers.run_suite(probe, files)
    probe.finished = nio.control.event()
    local merged = {}
    probe.on_results = function(results)
        for id, result in pairs(results) do
            merged[id] = result
        end
        for _, file in ipairs(files) do
            if not merged[file] then return end
        end
        probe.finished.set()
    end
    require("neotest").run.run({ suite = true })

    wait_for_results(probe)
    local adapter_id = probe.client:get_adapters()[1]
    return probe.client:get_position(nil, { adapter = adapter_id }), merged
end

--- Errors unless `executable` holds the path of `source`, the way the adapter
--- finds an executable: a build made elsewhere, such as in the container for
--- specs run on the host, embeds other paths. Says so up front, rather than
--- through a run that never finishes.
function helpers.require_build(executable, source)
    local file = io.open(executable, "rb")
    local content = file and file:read("*a")
    if file then file:close() end
    if not (content and content:find(source, 1, true)) then
        error(
            ("%s %s, not here: build the fixture where the specs run, e.g. in its container"):format(
                executable,
                content and ("was built for other paths than " .. source) or "is missing"
            )
        )
    end
end

return helpers
