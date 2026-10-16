-- GTest/GMock through the adapter's own functions.
local nio = require("nio")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

describe("GTest", function()
    local file = helpers.fixture("colcon/src/toolbox/greeter/test/greeter_test.cpp")

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
        local spec = adapter.build_spec({ tree = tree })
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
