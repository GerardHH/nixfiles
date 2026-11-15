-- The review display: the changes shown in the files, inline as extmarks or
-- side by side against the index, started by `review_update` and ended by
-- `review_stop`; `toggle_review_layout` switches between the two.
local helpers = require("tests.helpers")
local agent_review = require("agent_review")

local diff_marks_namespace = vim.api.nvim_create_namespace("agent_review_diff")

-- A repository whose display.lua has a changed line (2), an added line (4)
-- and a removed line (after 5), opened in the current window; returns the
-- root and the file's buffer.
local function open_changed_file()
    local repository_root = helpers.make_repository({ ["display.lua"] = { "a", "b", "c", "d", "gone", "e" } })
    helpers.write(repository_root, "display.lua", { "a", "B", "c", "added", "d", "e" })
    vim.cmd.edit(repository_root .. "/display.lua")
    return repository_root, vim.api.nvim_get_current_buf()
end

-- The buffer's marks as { row (1-based), kind, value }, sorted by row.
local function marks_of(buffer_number)
    local mark_summaries = {}
    local buffer_marks = vim.api.nvim_buf_get_extmarks(buffer_number, diff_marks_namespace, 0, -1, { details = true })
    for _, buffer_mark in ipairs(buffer_marks) do
        local mark_row, mark_details = buffer_mark[2] + 1, buffer_mark[4]
        if mark_details.line_hl_group then
            table.insert(mark_summaries, { mark_row, "line", mark_details.line_hl_group })
        end
        if mark_details.virt_lines then
            local virtual_texts = {}
            for _, virtual_line in ipairs(mark_details.virt_lines) do
                table.insert(virtual_texts, virtual_line[1][1] .. " (" .. virtual_line[1][2] .. ")")
            end
            local placement = mark_details.virt_lines_above and "above" or "below"
            table.insert(mark_summaries, { mark_row, placement, table.concat(virtual_texts, "|") })
        end
    end
    table.sort(mark_summaries, function(left_mark, right_mark) return left_mark[1] < right_mark[1] end)
    return mark_summaries
end

describe("review display", function()
    local original_notify = vim.notify

    before_each(function()
        vim.notify = function() end
        vim.g.agent_review_layout = nil
    end)

    after_each(function()
        agent_review.review_stop()
        vim.notify = original_notify
        vim.g.agent_review_layout = nil
        vim.cmd("silent! only")
        vim.cmd("silent! %bwipeout!")
    end)

    it("marks the changes inline by default", function()
        local repository_root, buffer_number = open_changed_file()
        agent_review.review_update(helpers.collect(repository_root))
        assert.are.same({
            -- b became B: the old line above it, the new one as a change.
            { 2, "line", "DiffChange" },
            { 2, "above", "b (DiffDelete)" },
            -- A line only added.
            { 4, "line", "DiffAdd" },
            -- A line only removed: below the line before the gap.
            { 5, "below", "gone (DiffDelete)" },
        }, marks_of(buffer_number))
    end)

    it("shows a removal at the top of the file above line 1", function()
        local repository_root = helpers.make_repository({ ["top.lua"] = { "header", "body" } })
        helpers.write(repository_root, "top.lua", { "body" })
        vim.cmd.edit(repository_root .. "/top.lua")
        agent_review.review_update(helpers.collect(repository_root))
        assert.are.same({ { 1, "above", "header (DiffDelete)" } }, marks_of(vim.api.nvim_get_current_buf()))
    end)

    it("expands tabs in removed lines to the buffer's tabstop", function()
        local repository_root = helpers.make_repository({ ["tabs.lua"] = { "\tindented", "kept" } })
        helpers.write(repository_root, "tabs.lua", { "kept" })
        vim.cmd.edit(repository_root .. "/tabs.lua")
        vim.bo.tabstop = 4
        agent_review.review_update(helpers.collect(repository_root))
        assert.are.same({ { 1, "above", "    indented (DiffDelete)" } }, marks_of(vim.api.nvim_get_current_buf()))
    end)

    it("marks a file opened during the review", function()
        local repository_root = helpers.make_repository({
            ["first.lua"] = { "a" },
            ["second.lua"] = { "a" },
        })
        helpers.write(repository_root, "first.lua", { "A" })
        helpers.write(repository_root, "second.lua", { "A" })
        vim.cmd.edit(repository_root .. "/first.lua")
        agent_review.review_update(helpers.collect(repository_root))
        vim.cmd.edit(repository_root .. "/second.lua")
        assert.are.same({
            { 1, "line", "DiffChange" },
            { 1, "above", "a (DiffDelete)" },
        }, marks_of(vim.api.nvim_get_current_buf()))
    end)

    it("clears the marks when the review stops", function()
        local repository_root, buffer_number = open_changed_file()
        agent_review.review_update(helpers.collect(repository_root))
        agent_review.review_stop()
        assert.are.same({}, marks_of(buffer_number))
    end)

    it("shows the index version side by side, in diff mode", function()
        vim.g.agent_review_layout = "side_by_side"
        local repository_root, buffer_number = open_changed_file()
        local file_window = vim.api.nvim_get_current_win()
        agent_review.review_update(helpers.collect(repository_root))
        local tab_windows = vim.api.nvim_tabpage_list_wins(0)
        assert.are.equal(2, #tab_windows)
        local index_window = tab_windows[1] == file_window and tab_windows[2] or tab_windows[1]
        local index_buffer = vim.api.nvim_win_get_buf(index_window)
        -- The index window is left of the file, with the file as committed.
        assert.is_true(vim.fn.win_screenpos(index_window)[2] < vim.fn.win_screenpos(file_window)[2])
        assert.are.same({ "a", "b", "c", "d", "gone", "e" }, vim.api.nvim_buf_get_lines(index_buffer, 0, -1, false))
        assert.is_true(vim.wo[index_window].diff)
        assert.is_true(vim.wo[file_window].diff)
        -- No inline marks in this layout.
        assert.are.same({}, marks_of(buffer_number))
        agent_review.review_stop()
        assert.are.same({ file_window }, vim.api.nvim_tabpage_list_wins(0))
        assert.is_false(vim.wo[file_window].diff)
    end)

    it("switches layouts during a review, and remembers the choice", function()
        local repository_root, buffer_number = open_changed_file()
        agent_review.review_update(helpers.collect(repository_root))
        agent_review.toggle_review_layout()
        assert.are.equal("side_by_side", vim.g.agent_review_layout)
        assert.are.equal(2, #vim.api.nvim_tabpage_list_wins(0))
        assert.are.same({}, marks_of(buffer_number))
        agent_review.toggle_review_layout()
        assert.are.equal("inline", vim.g.agent_review_layout)
        assert.are.equal(1, #vim.api.nvim_tabpage_list_wins(0))
        assert.is_true(#marks_of(buffer_number) > 0)
    end)

    it("only sets the next layout outside a review", function()
        agent_review.toggle_review_layout()
        assert.are.equal("side_by_side", vim.g.agent_review_layout)
        assert.are.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    end)
end)
