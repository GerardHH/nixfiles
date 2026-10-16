-- Catch2 through the adapter's own functions, without neotest's client: the
-- path that worked when the integration run hung.
local nio = require("nio")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

describe("Catch2", function()
    local root = helpers.fixture("cmake-catch2")
    local file = helpers.fixture("cmake-catch2/test/calculator_test.cpp")

    it("takes the source for a test file", function() assert.is_true(adapter.is_test_file(file)) end)

    it(
        "finds the project root by its build directory",
        function() assert.equals(root, adapter.root(vim.fs.dirname(file))) end
    )

    it("discovers the test cases", function()
        local tree = adapter.discover_positions(file)
        assert.is_not_nil(tree, "no positions: framework not detected?")
        assert.same(
            { "add sums two integers", "divide", "mean of a range", "deliberately failing" },
            helpers.test_names(tree)
        )
    end)

    it("runs the file and reads the results", function()
        local tree = adapter.discover_positions(file)
        local spec = adapter.build_spec({ tree = tree })
        assert.is_not_nil(spec)
        local result = helpers.run_spec(spec)
        assert.same({
            ["add sums two integers"] = "passed",
            divide = "passed",
            ["mean of a range"] = "passed",
            ["deliberately failing"] = "failed",
        }, helpers.statuses(tree, adapter.results(spec, result, tree)))
    end)

    -- Only the debugger's arguments break on failure, and only while
    -- break_on_failure is on (the default).
    it("breaks on failure in a debug run", function()
        local tree = adapter.discover_positions(file)
        local spec = adapter.build_spec({ tree = tree, strategy = "dap" })
        assert.is_true(vim.tbl_contains(spec.strategy.args, "--break"))
        assert.is_false(vim.tbl_contains(spec.command, "--break"))

        adapter.setup({ break_on_failure = false })
        local without = adapter.build_spec({ tree = tree, strategy = "dap" })
        adapter.setup({ break_on_failure = true })
        assert.is_false(vim.tbl_contains(without.strategy.args, "--break"))
    end)
end)

-- Discovery only: the executable is built in the container (see gtest_spec).
describe("Catch2 with GMock", function()
    local file = helpers.fixture("colcon/src/toolbox/greeter/test/greeter_catch2_test.cpp")

    it("discovers a file that includes gmock.h before Catch2", function()
        local tree = adapter.discover_positions(file)
        assert.is_not_nil(tree, "no positions: framework not detected?")
        assert.same({ "greet in the morning", "greet in the evening" }, helpers.test_names(tree))
    end)
end)
