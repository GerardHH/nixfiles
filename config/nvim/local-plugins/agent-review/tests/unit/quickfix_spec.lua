-- The quickfix front end: `to_quickfix` fills a new list from `collect`, and
-- moving the cursor onto a change in a file makes that entry the current one.
local helpers = require("tests.helpers")
local agent_review = require("agent_review")

-- A repository with two hunks in list.lua (lines 2 and 5-6) and a new file,
-- noted with a title; the hunk at 5-6 is from this round.
local function make_repository_with_notes()
    local repository_root = helpers.make_repository({ ["list.lua"] = { "a", "b", "c", "d", "e" } })
    helpers.write(repository_root, "list.lua", { "a", "B", "c", "d", "E", "E2" })
    helpers.write(repository_root, "added.lua", { "return {}" })
    helpers.write_notes(repository_root, {
        "# nvim: Shout b and e",
        "",
        "## list.lua",
        "",
        "- `2` — b shouts",
        "- `5-6` — e shouts twice · new",
        "- `9` — no change here",
    })
    return repository_root
end

describe("to_quickfix", function()
    local original_notify = vim.notify
    local notify_messages

    before_each(function()
        notify_messages = {}
        vim.notify = function(message) table.insert(notify_messages, message) end
    end)

    after_each(function()
        vim.notify = original_notify
        vim.cmd("cclose")
        vim.cmd("silent! %bwipeout!")
    end)

    it("fills a new list named after the notes, and opens it", function()
        local repository_root = make_repository_with_notes()
        vim.fn.chdir(repository_root)
        agent_review.to_quickfix()
        local agent_list = vim.fn.getqflist({ title = 1, items = 1 })
        assert.are.equal("nvim: Shout b and e", agent_list.title)
        local item_summaries = {}
        for _, quickfix_item in ipairs(agent_list.items) do
            table.insert(item_summaries, {
                file = vim.fs.basename(vim.api.nvim_buf_get_name(quickfix_item.bufnr)),
                lnum = quickfix_item.lnum,
                end_lnum = quickfix_item.end_lnum,
                text = quickfix_item.text,
            })
        end
        assert.are.same({
            -- This round's change first, marked; a range keeps its end.
            { file = "list.lua", lnum = 5, end_lnum = 6, text = "[new] e shouts twice" },
            -- A new file is one change without an end (quickfix gives 0);
            -- a single line's end is the line itself.
            { file = "added.lua", lnum = 1, end_lnum = 0, text = "new file" },
            { file = "list.lua", lnum = 2, end_lnum = 2, text = "b shouts" },
        }, item_summaries)
        -- The note on line 9 matches nothing.
        assert.is_truthy(notify_messages[1]:find("1 note(s)", 1, true))
        -- The quickfix window is open.
        local has_quickfix_window = false
        for _, window_info in ipairs(vim.fn.getwininfo()) do
            if window_info.quickfix == 1 then has_quickfix_window = true end
        end
        assert.is_true(has_quickfix_window)
    end)

    it("leaves the lists alone without changes", function()
        local repository_root = helpers.make_repository({ ["clean.lua"] = { "a" } })
        vim.fn.setqflist({}, " ", { title = "earlier list", items = {} })
        vim.fn.chdir(repository_root)
        agent_review.to_quickfix()
        assert.are.equal("earlier list", vim.fn.getqflist({ title = 1 }).title)
        assert.is_truthy(notify_messages[1]:find("^No unstaged changes"))
    end)

    it("follows the cursor onto the change under it", function()
        local repository_root = make_repository_with_notes()
        vim.fn.chdir(repository_root)
        agent_review.to_quickfix()
        -- From the quickfix window into the file, as after a jump.
        vim.cmd("wincmd p")
        vim.cmd.edit(repository_root .. "/list.lua")
        local function current_text()
            local agent_list = vim.fn.getqflist({ idx = 0, items = 1 })
            return agent_list.items[agent_list.idx].text
        end
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.cmd("doautocmd CursorMoved")
        assert.are.equal("b shouts", current_text())
        -- Inside the range 5-6, on its last line.
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        vim.cmd("doautocmd CursorMoved")
        assert.are.equal("[new] e shouts twice", current_text())
        -- Off any change: the list keeps its place.
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        vim.cmd("doautocmd CursorMoved")
        assert.are.equal("[new] e shouts twice", current_text())
    end)

    it("marks stale notes", function()
        local repository_root = make_repository_with_notes()
        -- A line added above every hunk after the notes: all of list.lua's
        -- notes are a line off now.
        helpers.write(repository_root, "list.lua", { "top", "a", "B", "c", "d", "E", "E2" }, 20)
        vim.fn.chdir(repository_root)
        agent_review.to_quickfix()
        local stale_texts = {}
        for _, quickfix_item in ipairs(vim.fn.getqflist()) do
            if quickfix_item.text:find("[stale?]", 1, true) then table.insert(stale_texts, quickfix_item.text) end
        end
        assert.is_true(#stale_texts > 0)
        local warned_stale = false
        for _, message in ipairs(notify_messages) do
            if message:find("list.lua", 1, true) and message:find("out of date", 1, true) then warned_stale = true end
        end
        assert.is_true(warned_stale)
    end)
end)
