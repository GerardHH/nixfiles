-- Stale notes: after the agent's turn, resetting or editing a hunk moves the
-- lines below it, so the notes' line numbers point at the wrong change.
-- `collect` lists the files whose notes may be stale (`stale_paths`) and
-- marks the entries there that show a note (`stale`); staging, a save that
-- changes nothing and an edit that keeps the lines in place don't count.
--
-- The example is the one from the design walkthrough: three hunks in
-- config.lua, A (a comment, lines 2-4), B (a changed line, 6) and C (an
-- added function, 8), each with a note. (The walkthrough had B right below
-- A, at 5, but git joins adjacent changes into one hunk; M.height keeps
-- them apart here.)
local helpers = require("tests.helpers")

-- config.lua as committed: the index before the agent's turn.
local committed_lines = {
    "local M = {}",
    "M.height = 24",
    "M.width = 80",
    "function M.setup() end",
    "return M",
}

-- config.lua after the agent's turn.
local agent_lines = {
    "local M = {}",
    "-- Window size,",
    "-- in cells,",
    "-- for the float.",
    "M.height = 24",
    "M.width = 100",
    "function M.setup() end",
    "function M.reset() end",
    "return M",
}

local notes_lines = {
    "# test: Size the float",
    "",
    "## config.lua",
    "",
    "- `2-4` — comment explaining the sizes",
    "- `6` — wider float",
    "- `8` — reset function",
}

-- A repository at the end of the agent's turn: config.lua changed at the
-- default time, the notes written 10 s later.
local function make_agent_round()
    local repository_root = helpers.make_repository({ ["config.lua"] = committed_lines })
    helpers.write(repository_root, "config.lua", agent_lines)
    helpers.write_notes(repository_root, notes_lines)
    return repository_root
end

-- agent_lines without the lines at `removed_indexes` (a set), as after
-- resetting the hunk they form.
local function agent_lines_without(removed_indexes)
    local kept_lines = {}
    for line_index, line_content in ipairs(agent_lines) do
        if not removed_indexes[line_index] then table.insert(kept_lines, line_content) end
    end
    return kept_lines
end

describe("stale notes", function()
    it("are not reported right after the agent's turn", function()
        local changes = helpers.collect(make_agent_round())
        assert.are.same({}, changes.stale_paths)
        assert.are.same({
            { lnum = 2, end_lnum = 4, text = "comment explaining the sizes", stale = false },
            { lnum = 6, end_lnum = 6, text = "wider float", stale = false },
            { lnum = 8, end_lnum = 8, text = "reset function", stale = false },
        }, helpers.entries_of(changes, "config.lua"))
    end)

    it("are reported after a hunk above others is reset", function()
        local repository_root = make_agent_round()
        -- Reset hunk A: the comment goes, B and C move up 3 lines.
        helpers.write(repository_root, "config.lua", agent_lines_without({ [2] = true, [3] = true, [4] = true }), 20)
        local changes = helpers.collect(repository_root)
        assert.are.same({ "config.lua" }, changes.stale_paths)
        -- The notes still land by line number: B (now line 3) gets A's note,
        -- marked; C (now line 5) gets none and shows its first line.
        assert.are.same({
            { lnum = 3, end_lnum = 3, text = "comment explaining the sizes", stale = true },
            { lnum = 5, end_lnum = 5, text = "function M.reset() end", stale = false },
        }, helpers.entries_of(changes, "config.lua"))
    end)

    it("are not reported after a hunk is staged", function()
        local repository_root = make_agent_round()
        -- Stage hunk C only: the index gets the new function, the working
        -- tree keeps its content and its time.
        helpers.stage(repository_root, "config.lua", {
            "local M = {}",
            "M.height = 24",
            "M.width = 80",
            "function M.setup() end",
            "function M.reset() end",
            "return M",
        })
        local changes = helpers.collect(repository_root)
        assert.are.same({}, changes.stale_paths)
        assert.are.same({
            { lnum = 2, end_lnum = 4, text = "comment explaining the sizes", stale = false },
            { lnum = 6, end_lnum = 6, text = "wider float", stale = false },
        }, helpers.entries_of(changes, "config.lua"))
        -- C's note has no unstaged change left.
        assert.are.equal(1, changes.unmatched_count)
    end)

    it("are not reported after a save that changes nothing", function()
        local repository_root = make_agent_round()
        helpers.write(repository_root, "config.lua", agent_lines, 20)
        assert.are.same({}, helpers.collect(repository_root).stale_paths)
    end)

    it("are not reported after an edit that keeps every hunk's lines", function()
        local repository_root = make_agent_round()
        local edited_lines = vim.deepcopy(agent_lines)
        edited_lines[6] = "M.width = 120"
        helpers.write(repository_root, "config.lua", edited_lines, 20)
        local changes = helpers.collect(repository_root)
        assert.are.same({}, changes.stale_paths)
        assert.are.equal("wider float", helpers.entries_of(changes, "config.lua")[2].text)
    end)

    it("are reported after an edit that changes a hunk's size", function()
        local repository_root = make_agent_round()
        local edited_lines = vim.deepcopy(agent_lines)
        table.insert(edited_lines, 5, "-- and its margins.")
        helpers.write(repository_root, "config.lua", edited_lines, 20)
        assert.are.same({ "config.lua" }, helpers.collect(repository_root).stale_paths)
    end)

    it("are reported when a reset moves a note onto another hunk's lines", function()
        -- Hunk A adds 2 lines and B and C are 2 lines apart, so resetting A
        -- moves C exactly onto B's old line: C's hunk lines up with B's note.
        -- The other notes, left without a hunk, still give it away.
        local repository_root = helpers.make_repository({ ["list.lua"] = { "a", "b", "c", "d", "e", "f" } })
        helpers.write(repository_root, "list.lua", { "a", "A2", "A3", "b", "c", "D", "e", "F" })
        helpers.write_notes(repository_root, {
            "## list.lua",
            "",
            "- `2-3` — added A2 and A3",
            "- `6` — d to D",
            "- `8` — f to F",
        })
        -- Reset A: D moves to 4, F to 6, where B's note points.
        helpers.write(repository_root, "list.lua", { "a", "b", "c", "D", "e", "F" }, 20)
        local changes = helpers.collect(repository_root)
        assert.are.same({ "list.lua" }, changes.stale_paths)
        assert.are.same({
            { lnum = 4, end_lnum = 4, text = "D", stale = false },
            { lnum = 6, end_lnum = 6, text = "d to D", stale = true },
        }, helpers.entries_of(changes, "list.lua"))
    end)

    it("are reported per file", function()
        local repository_root = helpers.make_repository({
            ["config.lua"] = committed_lines,
            ["other.lua"] = { "return 1" },
        })
        helpers.write(repository_root, "config.lua", agent_lines)
        helpers.write(repository_root, "other.lua", { "return 2" })
        local other_notes = vim.list_extend(vim.deepcopy(notes_lines), {
            "",
            "## other.lua",
            "",
            "- `1` — returns 2",
        })
        helpers.write_notes(repository_root, other_notes)
        -- Only other.lua shifts, by a line added above its hunk.
        helpers.write(repository_root, "other.lua", { "-- comment", "return 2" }, 20)
        local changes = helpers.collect(repository_root)
        assert.are.same({ "other.lua" }, changes.stale_paths)
        assert.is_false(helpers.entries_of(changes, "config.lua")[1].stale)
    end)

    it("are not reported for a new file rewritten after the notes", function()
        local repository_root = make_agent_round()
        helpers.write(repository_root, "new.lua", { "return {}" })
        helpers.write_notes(repository_root, { "## new.lua", "", "- `1` — new module" })
        -- A new file is one change as a whole, so its lines can't drift.
        helpers.write(repository_root, "new.lua", { "-- first", "return {}" }, 20)
        local changes = helpers.collect(repository_root)
        assert.are.same({}, changes.stale_paths)
        assert.are.equal("new module", helpers.entries_of(changes, "new.lua")[1].text)
    end)

    it("are not reported without a notes file", function()
        local repository_root = helpers.make_repository({ ["config.lua"] = committed_lines })
        helpers.write(repository_root, "config.lua", agent_lines, 20)
        assert.are.same({}, helpers.collect(repository_root).stale_paths)
    end)
end)

describe("warn_stale", function()
    local agent_review = require("agent_review")
    local original_notify = vim.notify
    local notify_messages

    before_each(function()
        notify_messages = {}
        vim.notify = function(message) table.insert(notify_messages, message) end
    end)

    after_each(function() vim.notify = original_notify end)

    it("warns once per set of stale files", function()
        agent_review.warn_stale({ stale_paths = {} })
        assert.are.equal(0, #notify_messages)
        agent_review.warn_stale({ stale_paths = { "config.lua" } })
        agent_review.warn_stale({ stale_paths = { "config.lua" } })
        assert.are.equal(1, #notify_messages)
        assert.is_truthy(notify_messages[1]:find("config.lua", 1, true))
        agent_review.warn_stale({ stale_paths = { "config.lua", "other.lua" } })
        assert.are.equal(2, #notify_messages)
        -- Stale again after a fresh round warns again.
        agent_review.warn_stale({ stale_paths = {} })
        agent_review.warn_stale({ stale_paths = { "config.lua" } })
        assert.are.equal(3, #notify_messages)
    end)
end)
