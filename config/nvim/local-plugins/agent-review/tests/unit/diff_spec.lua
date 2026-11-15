-- What `collect` makes of git's view of the working tree, without notes:
-- one entry per hunk, one per new file, one per deleted file, sorted, with
-- the text an entry shows when no note names it.
local helpers = require("tests.helpers")

-- The entries of `changes` for one path, with every field `collect` sets.
local function full_entries_of(changes, relative_path)
    local path_entries = {}
    for _, change_entry in ipairs(changes.entries) do
        if change_entry.path == relative_path then table.insert(path_entries, change_entry) end
    end
    return path_entries
end

describe("collect", function()
    it("gives each hunk its working-tree lines and its first added line", function()
        local repository_root = helpers.make_repository({ ["hunks.lua"] = { "a", "b", "c", "d", "e" } })
        helpers.write(repository_root, "hunks.lua", { "a", "B", "B2", "c", "d", "e", "f" })
        local hunk_entries = full_entries_of(helpers.collect(repository_root), "hunks.lua")
        assert.are.equal(2, #hunk_entries)
        -- b became B and B2: lines 2-3, replacing one removed line.
        assert.are.equal(2, hunk_entries[1].lnum)
        assert.are.equal(3, hunk_entries[1].end_lnum)
        assert.are.equal("B", hunk_entries[1].text)
        assert.are.same({ "b" }, hunk_entries[1].removed_lines)
        assert.are.equal(2, hunk_entries[1].added_count)
        -- f added at the end: line 7, nothing removed.
        assert.are.equal(7, hunk_entries[2].lnum)
        assert.are.equal(7, hunk_entries[2].end_lnum)
        assert.are.same({}, hunk_entries[2].removed_lines)
    end)

    it("shows the first removed line for a hunk that only removes", function()
        local repository_root = helpers.make_repository({ ["removal.lua"] = { "a", "b", "c" } })
        helpers.write(repository_root, "removal.lua", { "a", "c" })
        local removal_entry = full_entries_of(helpers.collect(repository_root), "removal.lua")[1]
        assert.are.equal("removed: b", removal_entry.text)
        -- git's new_start is the line before the gap.
        assert.are.equal(1, removal_entry.lnum)
        assert.are.equal(1, removal_entry.end_lnum)
        assert.are.equal(0, removal_entry.added_count)
    end)

    it("reads a removed line that looks like a diff header as a removed line", function()
        -- `-- comment` removed reads `--- comment` in the diff.
        local repository_root = helpers.make_repository({ ["header.lua"] = { "-- comment", "code" } })
        helpers.write(repository_root, "header.lua", { "code" })
        local removal_entry = full_entries_of(helpers.collect(repository_root), "header.lua")[1]
        assert.are.equal("removed: -- comment", removal_entry.text)
    end)

    it("makes a new file one change as a whole, and leaves out the notes file", function()
        local repository_root = helpers.make_repository({ ["kept.lua"] = { "kept" } })
        helpers.write(repository_root, "new dir/new file.lua", { "one", "two" })
        helpers.write_notes(repository_root, { "# Notes only" })
        local changes = helpers.collect(repository_root)
        assert.are.same({
            { lnum = 1, end_lnum = math.huge, text = "new file", stale = false },
        }, helpers.entries_of(changes, "new dir/new file.lua"))
        assert.are.same({}, helpers.entries_of(changes, ".agent-notes.md"))
    end)

    it("makes a deleted file one entry with nothing to open", function()
        local repository_root = helpers.make_repository({ ["gone.lua"] = { "one", "two" } })
        os.remove(repository_root .. "/gone.lua")
        local deleted_entry = full_entries_of(helpers.collect(repository_root), "gone.lua")[1]
        assert.is_true(deleted_entry.deleted)
        assert.are.equal("deleted file", deleted_entry.text)
        assert.are.equal(1, deleted_entry.lnum)
    end)

    it("keeps non-ASCII paths as they are", function()
        local repository_root = helpers.make_repository({ ["café.lua"] = { "a" } })
        helpers.write(repository_root, "café.lua", { "A" })
        assert.are.equal(1, #helpers.entries_of(helpers.collect(repository_root), "café.lua"))
    end)

    it("sorts this round's changes first, then by path and line", function()
        local repository_root = helpers.make_repository({
            ["a.lua"] = { "1", "2", "3", "4" },
            ["b.lua"] = { "1", "2", "3", "4" },
        })
        helpers.write(repository_root, "a.lua", { "ONE", "2", "3", "FOUR" })
        helpers.write(repository_root, "b.lua", { "ONE", "2", "3", "FOUR" })
        helpers.write_notes(repository_root, {
            "## b.lua",
            "",
            "- `4` — this round · new",
            "- `1` — earlier",
        })
        local sorted_positions = {}
        for _, change_entry in ipairs(helpers.collect(repository_root).entries) do
            table.insert(sorted_positions, change_entry.path .. ":" .. change_entry.lnum)
        end
        assert.are.same({ "b.lua:4", "a.lua:1", "a.lua:4", "b.lua:1" }, sorted_positions)
    end)

    it("returns an error outside a repository", function()
        local outside_directory = vim.fn.tempname()
        vim.fn.mkdir(outside_directory, "p")
        vim.fn.chdir(outside_directory)
        local changes, collect_error = require("agent_review").collect()
        assert.is_nil(changes)
        assert.is_truthy(collect_error:find("^Not in a git repository"))
    end)
end)
