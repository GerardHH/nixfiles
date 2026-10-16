-- A crashing Catch2 test through neotest itself, as <leader>tf runs it: in a
-- pty, with the exit code nvim reports for a signal. The run must finish,
-- with the crash and the tests it kept from running reported (see
-- tests/unit/crash_spec.lua for each framework; GTest's crash runs through
-- neotest in tests/container).
local nio = require("nio")
local helpers = require("tests.helpers")

local it = nio.tests.it

describe("neotest with a crashing Catch2 test", function()
    local probe = helpers.start_neotest(helpers.fixture("cmake-catch2"))
    local file = helpers.fixture("cmake-catch2/test/crash_test.cpp")

    it("finishes the run and reports the crash", function()
        local tree, results = helpers.run_file(probe, file)
        assert.same({
            ["passes before the crash"] = "passed",
            ["throws inside an assertion"] = "failed",
            ["throws outside an assertion"] = "failed",
            ["throws after an assertion"] = "failed",
            segfaults = "failed",
            ["not run after the crash"] = "skipped",
        }, helpers.statuses(tree, results))

        local by_name = helpers.test_results(tree, results)
        assert.is_not_nil(by_name.segfaults.short:find("Crashed: SIGSEGV", 1, true), by_name.segfaults.short)
        assert.equals("not run: the run crashed before it, in segfaults", by_name["not run after the crash"].short)
    end)
end)
