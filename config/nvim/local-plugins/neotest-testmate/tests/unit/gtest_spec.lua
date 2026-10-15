-- GTest/GMock through the adapter's own functions. The fixture's executable
-- is built in the container, so build_spec can't find it on the host (it
-- embeds /workspaces paths): run it directly with gtest.arguments instead.
local nio = require("nio")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

describe("GTest", function()
    local file = helpers.fixture("colcon-catch2/src/toolbox/greeter/test/greeter_test.cpp")
    local executable = helpers.fixture("colcon-catch2/build/greeter/greeter_test")

    it("discovers a file that includes only gmock.h", function()
        local tree = adapter.discover_positions(file)
        assert.is_not_nil(tree, "no positions: framework not detected?")
        assert.same({
            "Greet.UsesTheName",
            "GreetEvening.SaysGoodEvening",
            "GreetAfternoon.CoversEachHour",
            "GreetTyped.AcceptsHourType",
            "Greet.SkipsItself",
            "Greet.DeliberatelyFailing",
        }, helpers.test_names(tree))
    end)

    it("sums up TEST_P and TYPED_TEST instances in the results", function()
        local tree = adapter.discover_positions(file)
        local tests = {}
        for _, node in tree:iter_nodes() do
            if node:data().type == "test" then table.insert(tests, node:data()) end
        end
        local report = nio.fn.tempname()
        local spec = {
            command = vim.list_extend({ executable }, require("neotest-testmate.gtest").arguments(tests, report)),
            context = { framework = "gtest", report = report, debug = false },
        }
        local result = helpers.run_spec(spec)
        assert.same({
            ["Greet.UsesTheName"] = "passed",
            ["GreetEvening.SaysGoodEvening"] = "passed",
            ["GreetAfternoon.CoversEachHour"] = "passed",
            ["GreetTyped.AcceptsHourType"] = "passed",
            ["Greet.SkipsItself"] = "skipped",
            ["Greet.DeliberatelyFailing"] = "failed",
        }, helpers.statuses(tree, adapter.results(spec, result, tree)))
    end)
end)
