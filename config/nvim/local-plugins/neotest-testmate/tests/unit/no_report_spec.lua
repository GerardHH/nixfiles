-- A run that leaves no report because the executable never got to its tests,
-- as in a colcon workspace not sourced before starting nvim: the dynamic
-- loader can't find a shared library and exits with 127. Every test fails
-- with the exit code, a hint, and the end of the output, where the loader
-- says which library. Or it crashed before the first test, e.g. in a static
-- initializer: then the signal. The fixtures link statically and crash only
-- inside tests, so the run's result is made up here; the spec and the tests
-- are real.
local nio = require("nio")
local lib = require("neotest.lib")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

--- A result as helpers.run_spec gives it, for a run that printed `lines`
--- (through a pty, as neotest runs it: lines end in \r\n) and exited with
--- `code`.
local function made_up_result(code, lines)
    local output = nio.fn.tempname()
    lib.files.write(output, table.concat(lines, "\r\n"))
    return { code = code, output = output }
end

--- Asserts that `text` holds `part`, showing both when it doesn't.
local function contains(part, text)
    assert.is_true(text:find(part, 1, true) ~= nil, ("%q not in:\n%s"):format(part, text))
end

describe("a run that leaves no report", function()
    local file = helpers.fixture("colcon/src/toolbox/greeter/test/greeter_test.cpp")
    local loader_error =
        "greeter_test: error while loading shared libraries: libgreeter.so: cannot open shared object file: No such file or directory"

    it("fails each test with the exit code, a hint and the end of the output", function()
        local tree = adapter.discover_positions(file)
        local spec = adapter.build_spec({ tree = tree })
        local output = { "printed first, left out", "2", "3", "4", "5", loader_error }
        local results = helpers.test_results(tree, adapter.results(spec, made_up_result(127, output), tree))

        for name, result in pairs(results) do
            assert.equals("failed", result.status, name)
            contains("Exited with code 127 without writing a complete report", result.short)
            contains("source install/setup.bash", result.short)
            contains(loader_error, result.short)
            assert.is_nil(result.short:find("printed first", 1, true), "more than the end of the output")
            assert.is_nil(result.short:find("\r", 1, true), "the pty's \\r left in")
        end
    end)

    it("names the signal of a crash before the first test, which nothing printed", function()
        local tree = adapter.discover_positions(file)
        local spec = adapter.build_spec({ tree = tree })
        local results = helpers.test_results(tree, adapter.results(spec, made_up_result(139, {}), tree))

        for name, result in pairs(results) do
            assert.equals("failed", result.status, name)
            assert.equals("Crashed: SIGSEGV (exit code 139) without writing a complete report", result.short)
        end
    end)

    it("fails each test with the hint in a debug run, which has no output", function()
        local tree = adapter.discover_positions(file)
        local spec = adapter.build_spec({ tree = tree, strategy = "dap" })
        local results = helpers.test_results(tree, adapter.results(spec, made_up_result(127, {}), tree))

        -- Not empty: neotest would mark every test failed without a message.
        assert.is_true(next(results) ~= nil, "no results")
        for name, result in pairs(results) do
            assert.equals("failed", result.status, name)
            contains("source install/setup.bash", result.short)
        end
    end)
end)
