-- A file without test cases through neotest itself: the run must finish
-- with the file skipped. Before, neotest logged "doesn't support running
-- files" and left the file running forever, with no process to stop.
local nio = require("nio")
local helpers = require("tests.helpers")

local it = nio.tests.it

describe("neotest with a file without test cases", function()
    local probe = helpers.start_neotest(helpers.fixture("colcon"))
    local main = helpers.fixture("colcon/src/toolbox/calculator/test/main.cpp")

    it("finishes the run and marks the file skipped", function()
        local _, results = helpers.run_file(probe, main)
        assert.is_not_nil(results[main], "no result for the file")
        assert.equals("skipped", results[main].status)
        assert.equals("No test cases in file main.cpp", results[main].short)
    end)
end)
