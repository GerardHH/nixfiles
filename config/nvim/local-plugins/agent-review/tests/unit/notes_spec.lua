-- The notes file format (README.md, "The notes file"): headings, locations,
-- separators, the "· new" mark, and items that wrap over several lines, as
-- `collect` reads them onto the unstaged changes.
local helpers = require("tests.helpers")

-- A repository with two changed files: notes.lua (lines 2 and 4 changed)
-- and other.lua (line 1 changed), written before the notes.
local function make_repository_with_changes()
    local repository_root = helpers.make_repository({
        ["notes.lua"] = { "one", "two", "three", "four", "five" },
        ["other.lua"] = { "return 1" },
    })
    helpers.write(repository_root, "notes.lua", { "one", "TWO", "three", "FOUR", "five" })
    helpers.write(repository_root, "other.lua", { "return 2" })
    return repository_root
end

describe("notes", function()
    it("attach to the hunks they name, with the title read", function()
        local repository_root = make_repository_with_changes()
        helpers.write_notes(repository_root, {
            "# nvim: Shout two and four",
            "",
            "Free text, not a note.",
            "",
            "## notes.lua",
            "",
            "- `2` — two shouts",
            "- `4` — four shouts",
        })
        local changes = helpers.collect(repository_root)
        assert.are.equal("nvim: Shout two and four", changes.title)
        assert.are.same({
            { lnum = 2, end_lnum = 2, text = "two shouts", stale = false },
            { lnum = 4, end_lnum = 4, text = "four shouts", stale = false },
        }, helpers.entries_of(changes, "notes.lua"))
        assert.are.equal(0, changes.unmatched_count)
    end)

    it("read an item that wraps over several lines whole", function()
        local repository_root = make_repository_with_changes()
        helpers.write_notes(repository_root, {
            "## notes.lua",
            "",
            -- The wrap cut a note off after "and" once, before an indented
            -- line starting with backticks.
            "- `2` — first part of the why, and",
            "  `second part` on the next line",
            -- Locations wrap too.
            "- `4`,",
            "  `other.lua:1` — shared",
            "  over three lines",
            "",
            "A paragraph after a blank line is no part of the item.",
        })
        local changes = helpers.collect(repository_root)
        assert.are.equal(
            "first part of the why, and `second part` on the next line",
            helpers.entries_of(changes, "notes.lua")[1].text
        )
        assert.are.equal("shared over three lines", helpers.entries_of(changes, "notes.lua")[2].text)
        assert.are.equal("shared over three lines", helpers.entries_of(changes, "other.lua")[1].text)
    end)

    it("take a colon, an en dash or a hyphen as the separator", function()
        local repository_root = make_repository_with_changes()
        helpers.write_notes(repository_root, {
            "## notes.lua",
            "",
            "- `2`: with a colon",
            "- 4 – with an en dash, location without backticks",
            "",
            "## other.lua",
            "",
            "* `1` - with a hyphen, as a `*` item",
        })
        local changes = helpers.collect(repository_root)
        assert.are.equal("with a colon", helpers.entries_of(changes, "notes.lua")[1].text)
        assert.are.equal(
            "with an en dash, location without backticks",
            helpers.entries_of(changes, "notes.lua")[2].text
        )
        assert.are.equal("with a hyphen, as a `*` item", helpers.entries_of(changes, "other.lua")[1].text)
    end)

    it("mark this round's changes by a trailing · new, also after a wrap", function()
        local repository_root = make_repository_with_changes()
        helpers.write_notes(repository_root, {
            "## notes.lua",
            "",
            "- `2` — earlier round",
            "- `4` — this round, the mark wrapped onto ·",
            "  new",
        })
        local changes = helpers.collect(repository_root)
        local entries_by_line = {}
        for _, change_entry in ipairs(changes.entries) do
            if change_entry.path == "notes.lua" then entries_by_line[change_entry.lnum] = change_entry end
        end
        assert.is_falsy(entries_by_line[2].new)
        assert.is_true(entries_by_line[4].new)
        assert.are.equal("this round, the mark wrapped onto", entries_by_line[4].text)
        -- This round's changes sort first.
        assert.are.equal(4, changes.entries[1].lnum)
    end)

    it("that match no change are counted, and entries without one show their first line", function()
        local repository_root = make_repository_with_changes()
        helpers.write_notes(repository_root, {
            "## notes.lua",
            "",
            "- `2` — two shouts",
            "- `3` — no change here",
        })
        local changes = helpers.collect(repository_root)
        assert.are.equal(1, changes.unmatched_count)
        assert.are.equal("FOUR", helpers.entries_of(changes, "notes.lua")[2].text)
    end)

    it("place a note at line 0 on a removal at the top of the file", function()
        local repository_root = helpers.make_repository({ ["top.lua"] = { "header", "body" } })
        helpers.write(repository_root, "top.lua", { "body" })
        -- git gives this hunk as `@@ -1 +0,0 @@`: line 0 in the working tree.
        helpers.write_notes(repository_root, { "## top.lua", "", "- `0` — header dropped" })
        local changes = helpers.collect(repository_root)
        assert.are.same({
            { lnum = 1, end_lnum = 1, text = "header dropped", stale = false },
        }, helpers.entries_of(changes, "top.lua"))
    end)
end)
