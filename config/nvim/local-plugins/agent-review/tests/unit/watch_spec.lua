-- The notes watch: while on, a rewrite of the notes file reloads changed
-- buffers and fires `User AgentReviewNotesChanged` once, after a short
-- debounce; other files and a stopped watch fire nothing.
local helpers = require("tests.helpers")
local agent_review = require("agent_review")

-- How long to wait for an event: well past the 200 ms debounce.
local wait_ms = 1000

describe("watch_notes", function()
    local fired_count
    local event_group

    before_each(function()
        fired_count = 0
        event_group = vim.api.nvim_create_augroup("watch_spec", { clear = true })
        vim.api.nvim_create_autocmd("User", {
            group = event_group,
            pattern = "AgentReviewNotesChanged",
            callback = function() fired_count = fired_count + 1 end,
        })
    end)

    after_each(function()
        agent_review.unwatch_notes()
        vim.api.nvim_del_augroup_by_id(event_group)
        vim.cmd("silent! %bwipeout!")
    end)

    -- Lets libuv's events and the debounce timer run.
    local function settle()
        vim.wait(wait_ms, function() return false end)
    end

    it("fires once when the notes are rewritten in place", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        agent_review.watch_notes(repository_root)
        helpers.write_notes(repository_root, { "# first" })
        settle()
        assert.are.equal(1, fired_count)
    end)

    it("fires when a new file is renamed over the notes", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        helpers.write_notes(repository_root, { "# before" })
        agent_review.watch_notes(repository_root)
        local temporary_path = repository_root .. "/.agent-notes.md.tmp"
        vim.fn.writefile({ "# after" }, temporary_path)
        assert(vim.uv.fs_rename(temporary_path, repository_root .. "/.agent-notes.md"))
        settle()
        assert.are.equal(1, fired_count)
    end)

    it("ignores other files", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        agent_review.watch_notes(repository_root)
        helpers.write(repository_root, "file.lua", { "b" })
        settle()
        assert.are.equal(0, fired_count)
    end)

    it("watches once per repository, however often it's started", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        agent_review.watch_notes(repository_root)
        agent_review.watch_notes(repository_root)
        helpers.write_notes(repository_root, { "# notes" })
        settle()
        assert.are.equal(1, fired_count)
    end)

    it("stops on unwatch", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        agent_review.watch_notes(repository_root)
        agent_review.unwatch_notes()
        helpers.write_notes(repository_root, { "# notes" })
        settle()
        assert.are.equal(0, fired_count)
    end)

    it("moves to another repository", function()
        local first_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        local second_root = helpers.make_repository({ ["file.lua"] = { "a" } })
        agent_review.watch_notes(first_root)
        agent_review.watch_notes(second_root)
        helpers.write_notes(first_root, { "# first" })
        settle()
        assert.are.equal(0, fired_count)
        helpers.write_notes(second_root, { "# second" })
        settle()
        assert.are.equal(1, fired_count)
    end)

    it("reloads a buffer the agent changed", function()
        local repository_root = helpers.make_repository({ ["file.lua"] = { "before" } })
        vim.cmd.edit(repository_root .. "/file.lua")
        agent_review.watch_notes(repository_root)
        -- The agent's edit, then its notes; the buffer still shows the old
        -- text until nvim checks.
        helpers.write(repository_root, "file.lua", { "after" }, 5)
        helpers.write_notes(repository_root, { "# notes" })
        settle()
        assert.are.same({ "after" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
end)
