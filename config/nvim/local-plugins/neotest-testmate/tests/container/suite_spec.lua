-- A suite run of the colcon test bed through neotest itself, as <leader>tp
-- runs it: every test file in the workspace, Catch2 and GTest side by side.
-- Needs the workspace built for the paths the specs see, as the adapter finds
-- an executable by the source paths in it: so in the test bed's container,
-- after a colcon build (see `make container`).
local nio = require("nio")
local helpers = require("tests.helpers")

local it = nio.tests.it

local function source(relative) return helpers.fixture("colcon-catch2/src/toolbox/" .. relative) end

-- Status per test name, per file; an empty table for a file without tests.
local expected = {
    ["calculator/test/calculator_test.cpp"] = {
        ["add sums two integers"] = "passed",
        divide = "passed",
        ["mean of a range"] = "passed",
        ["deliberately failing"] = "failed",
    },
    ["calculator/test/main.cpp"] = {},
    ["text/test/text_test.cpp"] = {
        ["split on a delimiter"] = "passed",
        ["split keeps empty fields, even at the ends"] = "passed",
        ["to_upper converts ASCII letters"] = "passed",
        ["to_upper -> leaves digits alone"] = "passed",
    },
    ["text/test/main.cpp"] = {},
    ["greeter/test/greeter_test.cpp"] = {
        ["Greet.UsesTheName"] = "passed",
        ["GreetEvening.SaysGoodEvening"] = "passed",
        ["GreetAfternoon.CoversEachHour"] = "passed",
        ["GreetTyped.AcceptsHourType"] = "passed",
        ["Greet.SkipsItself"] = "skipped",
        ["Greet.DeliberatelyFailing"] = "failed",
    },
    -- Includes gmock.h before Catch2's header, and still runs as Catch2.
    ["greeter/test/greeter_catch2_test.cpp"] = {
        ["greet in the morning"] = "passed",
        ["greet in the evening"] = "passed",
    },
}

describe("neotest with a colcon workspace", function()
    -- Before neotest starts: with a build for other paths, the adapter can't
    -- find the executables and the suite run aborts.
    for executable, file in pairs({
        calculator_test = "calculator/test/calculator_test.cpp",
        text_test = "text/test/text_test.cpp",
        greeter_test = "greeter/test/greeter_test.cpp",
        greeter_catch2_test = "greeter/test/greeter_catch2_test.cpp",
    }) do
        local package = vim.split(file, "/")[1]
        helpers.require_build(helpers.fixture(("colcon-catch2/build/%s/%s"):format(package, executable)), source(file))
    end

    local probe = helpers.start_neotest(helpers.fixture("colcon-catch2"))
    local files = vim.tbl_map(source, vim.tbl_keys(expected))

    -- One suite run for all specs below.
    local tree, results
    local function run()
        if not results then
            tree, results = helpers.run_suite(probe, files)
        end
        return tree, results
    end

    it("runs each test file with its own framework", function()
        local suite, suite_results = run()
        for relative, statuses in pairs(expected) do
            local file = suite:get_key(source(relative))
            assert.is_not_nil(file, "not discovered: " .. relative)
            assert.same(statuses, helpers.statuses(file, suite_results), relative)
        end
    end)

    it("skips the files without test cases, saying why", function()
        local _, suite_results = run()
        for _, relative in ipairs({ "calculator/test/main.cpp", "text/test/main.cpp" }) do
            local result = suite_results[source(relative)]
            assert.is_not_nil(result, "no result for " .. relative)
            assert.equals("skipped", result.status)
            assert.equals("No test cases in file main.cpp", result.short)
        end
    end)
end)
