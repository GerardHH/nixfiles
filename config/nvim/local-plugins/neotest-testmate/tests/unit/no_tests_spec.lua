-- Positions without test cases: a test main.cpp with only CATCH_CONFIG_MAIN,
-- and a namespace of helpers. They must run nothing and come out skipped;
-- build_spec returning nil made neotest leave them running forever.
local nio = require("nio")
local Tree = require("neotest.types").Tree
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

--- Status and message per position id.
local function outcome(results)
    return vim.tbl_map(function(result) return { result.status, result.short } end, results)
end

describe("a position without test cases", function()
    it("runs nothing for a file and marks it skipped", function()
        local main = helpers.fixture("colcon/src/toolbox/calculator/test/main.cpp")
        local tree = adapter.discover_positions(main)
        assert.same({}, helpers.test_names(tree))

        local spec = adapter.build_spec({ tree = tree })
        assert.is_not_nil(spec, "nil leaves the file running in neotest")
        assert.same(
            { [main] = { "skipped", "No test cases in file main.cpp" } },
            outcome(adapter.results(spec, helpers.run_spec(spec), tree))
        )
    end)

    it("runs nothing for a namespace and marks it skipped", function()
        -- A file whose only namespace has no tests; built by hand, as the
        -- fixtures have no such namespace.
        local file = helpers.fixture("cmake-catch2/test/calculator_test.cpp")
        local id = file .. "::helpers"
        local tree = Tree.from_list({
            { type = "file", id = file, name = "calculator_test.cpp", path = file, range = { 0, 0, 30, 0 } },
            { { type = "namespace", id = id, name = "helpers", path = file, range = { 0, 0, 5, 0 } } },
        }, function(position) return position.id end)
        local namespace = tree:get_key(id)

        local spec = adapter.build_spec({ tree = namespace })
        assert.same(
            { [id] = { "skipped", "No test cases in namespace helpers" } },
            outcome(adapter.results(spec, helpers.run_spec(spec), namespace))
        )
    end)

    it("refuses to debug it, saying why", function()
        local main = helpers.fixture("colcon/src/toolbox/calculator/test/main.cpp")
        local tree = adapter.discover_positions(main)
        assert.has_error(
            function() adapter.build_spec({ tree = tree, strategy = "dap" }) end,
            "No test cases in file main.cpp"
        )
    end)
end)
