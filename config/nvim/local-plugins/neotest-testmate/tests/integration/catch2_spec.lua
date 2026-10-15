-- Catch2 through neotest itself, as <leader>tf runs it: client, discovery
-- (in neotest's child nvim) and the integrated strategy.
local nio = require("nio")
local helpers = require("tests.helpers")

local it = nio.tests.it

describe("neotest with Catch2", function()
    local probe = helpers.start_neotest(helpers.fixture("cmake-catch2"))
    local file = helpers.fixture("cmake-catch2/test/calculator_test.cpp")

    it("runs a file and reports its results", function()
        local tree, results = helpers.run_file(probe, file)
        assert.same({
            ["add sums two integers"] = "passed",
            divide = "passed",
            ["mean of a range"] = "passed",
            ["deliberately failing"] = "failed",
        }, helpers.statuses(tree, results))
    end)
end)
