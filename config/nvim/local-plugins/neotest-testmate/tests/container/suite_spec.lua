-- A suite run of the colcon fixture through neotest itself, as <leader>tp
-- runs it: every test file in the workspace, Catch2 and GTest side by side.
-- Needs the workspace built for the paths the specs see, as the adapter finds
-- an executable by the source paths in it: so in the fixture's container,
-- after a colcon build (see `make container`).
local nio = require("nio")
local helpers = require("tests.helpers")

local it = nio.tests.it

local function source(relative) return helpers.fixture("colcon/src/toolbox/" .. relative) end

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
    -- Crash on purpose, and must not hold up the rest of the suite (see
    -- tests/unit/crash_spec.lua for the messages).
    ["text/test/text_crash_test.cpp"] = {
        ["passes before the crash"] = "passed",
        ["throws inside an assertion"] = "failed",
        ["throws outside an assertion"] = "failed",
        ["throws after an assertion"] = "failed",
        segfaults = "failed",
        ["not run after the crash"] = "skipped",
    },
    ["greeter/test/greeter_crash_test.cpp"] = {
        ["Crash.PassesBefore"] = "passed",
        ["Crash.FailsBefore"] = "failed",
        ["Crash.ThrowsOutsideAnAssertion"] = "failed",
        ["Crash.Segfaults"] = "failed",
        ["Crash.NotRunAfter"] = "skipped",
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
        text_crash_test = "text/test/text_crash_test.cpp",
        greeter_crash_test = "greeter/test/greeter_crash_test.cpp",
    }) do
        local package = vim.split(file, "/")[1]
        helpers.require_build(helpers.fixture(("colcon/build/%s/%s"):format(package, executable)), source(file))
    end

    local probe = helpers.start_neotest(helpers.fixture("colcon"))
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

    -- Through neotest's pty, where GTest colours its output, and with the exit
    -- code nvim reports for a signal.
    it("reports GTest's crash from the console output", function()
        local suite, suite_results = run()
        local file = suite:get_key(source("greeter/test/greeter_crash_test.cpp"))
        local by_name = helpers.test_results(file, suite_results)
        assert.is_not_nil(by_name["Crash.Segfaults"].short:find("Crashed: SIGSEGV (exit code 139)", 1, true))
        assert.equals("not run: the run crashed before it, in Crash.Segfaults", by_name["Crash.NotRunAfter"].short)
    end)
end)
