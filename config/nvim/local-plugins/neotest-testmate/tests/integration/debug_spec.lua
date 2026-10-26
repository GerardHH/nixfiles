-- A debug run through neotest and codelldb, stopped at the break-on-failure
-- trap and ended there, so the executable writes no report: the tests keep
-- the results of the run before. neotest drops those as a run starts, and
-- marks every test it gets no result for failed, so the adapter returns them
-- itself (see tests/unit/no_report_spec.lua). Needs codelldb on PATH, which
-- nixfiles' nvim module brings, and ptrace, which the container allows.
local nio = require("nio")
local dap = require("dap")
local helpers = require("tests.helpers")

local it = nio.tests.it

-- As in nixfiles' config/nvim/lua/plugins/dap.lua.
dap.adapters.codelldb = { type = "executable", command = "codelldb" }

-- Ends the session as soon as it stops. From the listener rather than the
-- spec: nvim-dap yields when called from a coroutine, such as a nio task.
local stops = {}
dap.listeners.after.event_stopped.debug_spec = function(_, body)
    table.insert(stops, body.description or body.reason)
    vim.schedule(function() dap.terminate() end)
end

describe("neotest with a debug run ended at the trap", function()
    local probe = helpers.start_neotest(helpers.fixture("colcon"))
    local file = helpers.fixture("colcon/src/toolbox/greeter/test/greeter_test.cpp")

    it("keeps the results of the run before", function()
        local tree, before = helpers.run_file(probe, file)
        local statuses = helpers.statuses(tree, before)
        -- The trap needs a failing test; a passing one shows the results are
        -- kept, not just failed again.
        assert.equals("failed", statuses["Greet.DeliberatelyFailing"])
        assert.equals("passed", statuses["Greet.UsesTheName"])

        local _, after = helpers.run_file(probe, file, "dap")
        -- Stopped at the trap: a session that ran to the end would write a
        -- report, and give the same statuses anyway.
        assert.same({ "signal SIGTRAP" }, stops)
        assert.same(statuses, helpers.statuses(tree, after))
        assert.equals(
            helpers.test_results(tree, before)["Greet.DeliberatelyFailing"].short,
            helpers.test_results(tree, after)["Greet.DeliberatelyFailing"].short
        )
    end)
end)
