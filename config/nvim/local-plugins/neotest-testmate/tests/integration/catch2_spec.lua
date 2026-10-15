-- Catch2 through neotest itself, as <leader>tf runs it: client, discovery
-- (in neotest's child nvim) and the integrated strategy. A probe consumer
-- records the client's events, so a run that never finishes says how far it
-- got.
local nio = require("nio")
local helpers = require("tests.helpers")
local adapter = require("neotest-testmate")

local it = nio.tests.it

-- Less than PLENARY_TEST_TIMEOUT, so this spec fails with its own message.
local timeout = tonumber(vim.env.TESTMATE_TIMEOUT) or 30000

describe("neotest with Catch2", function()
    local root = helpers.fixture("cmake-catch2")
    local file = helpers.fixture("cmake-catch2/test/calculator_test.cpp")

    local events = {}
    local file_tree
    local results
    local finished = nio.control.event()

    -- neotest takes the project from the working directory.
    vim.fn.chdir(root)
    os.remove(vim.fn.stdpath("log") .. "/neotest.log")
    require("neotest").setup({
        log_level = vim.log.levels.DEBUG,
        adapters = { adapter },
        consumers = {
            probe = function(client)
                for _, event in ipairs({ "starting", "started", "discover_positions", "run" }) do
                    client.listeners[event] = function(_, tree)
                        table.insert(events, event)
                        if event == "discover_positions" and tree and tree:get_key(file) then
                            file_tree = tree:get_key(file)
                        end
                    end
                end
                client.listeners.results = function(_, adapter_results, partial)
                    table.insert(events, partial and "results (partial)" or "results")
                    if not partial then
                        results = vim.tbl_extend("force", results or {}, adapter_results)
                        finished.set()
                    end
                end
                return {}
            end,
        },
    })

    it("runs a file and reports its results", function()
        nio.api.nvim_command("edit " .. vim.fn.fnameescape(file))
        require("neotest").run.run(file)

        nio.first({ finished.wait, function() nio.sleep(timeout) end })
        if not finished.is_set() then
            error(
                ("No results after %d ms. Client events: %s\nEnd of neotest.log:\n%s"):format(
                    timeout,
                    #events > 0 and table.concat(events, ", ") or "none",
                    helpers.log_tail()
                )
            )
        end

        assert.is_not_nil(file_tree, "results came, but no discovery of the file")
        assert.same({
            ["add sums two integers"] = "passed",
            divide = "passed",
            ["mean of a range"] = "passed",
            ["deliberately failing"] = "failed",
        }, helpers.statuses(file_tree, results))
    end)
end)
