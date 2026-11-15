-- agent-review: review an agent's changes through git. The changes are what
-- isn't staged yet: one entry per hunk of `git diff` (working tree against
-- the index), one per untracked file. Staging is how a change gets
-- accepted, so the list is what's left to review. Built from git alone, so
-- it works the same for any agent; the agent explains its changes in a notes
-- file (format in README.md).
--
-- `M.collect` gathers the changes and their notes; two front ends show them:
-- trouble.nvim (`lua/trouble/sources/agent_review.lua`, `:Trouble
-- agent_review`), grouped by file, and the quickfix list (`M.to_quickfix`),
-- for `:cdo` and the like. While a review is on, the files show the changes
-- inline or side by side (`M.review_update`, `M.toggle_review_layout`).
-- Needs no plugin; trouble is optional.
--
-- While the quickfix list exists, moving the cursor onto one of its changes
-- in a buffer makes that entry the current one, so `:cnext` and the quickfix
-- window carry on from where I am, not from where I last jumped from the list.
--
-- Known issues: see README.md.
local M = {}

-- Markdown, so it reads well on its own and the same text can go in a chat
-- summary. Ignored through the global git ignore file, so it never shows as
-- untracked.
M.notes_file = ".agent-notes.md"

-- The id of the quickfix list this module filled last, so the cursor sync
-- only touches that list, never one from grep or diagnostics. nil until the
-- first fill.
local agent_list_id = nil

-- Makes the entry whose lines hold the cursor the current entry of our list.
-- Leaves the list alone when the cursor is on no change of it, so stepping
-- outside a hunk doesn't lose the place.
local function select_entry_under_cursor()
    if not agent_list_id or vim.bo.buftype == "quickfix" then return end
    local agent_list = vim.fn.getqflist({ id = agent_list_id, items = 1, idx = 0 })
    -- Gone from the history (nvim keeps ten lists): stop syncing.
    if agent_list.id == 0 or not agent_list.items then
        agent_list_id = nil
        return
    end
    local current_buffer = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    for item_index, quickfix_item in ipairs(agent_list.items) do
        if quickfix_item.bufnr == current_buffer then
            -- A new file is one change as a whole, marked when the list was
            -- filled; quickfix's end_lnum is 0 for a single line.
            local is_whole_file = type(quickfix_item.user_data) == "table" and quickfix_item.user_data.whole_file
            local last_line = quickfix_item.end_lnum > 0 and quickfix_item.end_lnum or quickfix_item.lnum
            if is_whole_file or (cursor_line >= quickfix_item.lnum and cursor_line <= last_line) then
                -- Only on a change of entry: setqflist redraws the window.
                if item_index ~= agent_list.idx then
                    vim.fn.setqflist({}, "a", { id = agent_list_id, idx = item_index })
                end
                return
            end
        end
    end
end

-- Runs git in the repository and returns its stdout, or nil and an error
-- message. quotePath off keeps non-ASCII paths as they are, instead of octal
-- escapes in quotes.
local function git(repository_root, git_arguments)
    local git_command = { "git", "-C", repository_root, "-c", "core.quotePath=false" }
    vim.list_extend(git_command, git_arguments)
    local git_result = vim.system(git_command, { text = true }):wait()
    if git_result.code ~= 0 then return nil, vim.trim(git_result.stderr) end
    return git_result.stdout
end

-- The repository around the current buffer's file, or around the working
-- directory for a buffer without a file (quickfix, help, a new buffer).
local function find_repository_root()
    local buffer_name = vim.api.nvim_buf_get_name(0)
    local is_file_buffer = buffer_name ~= "" and vim.bo.buftype == ""
    local start_directory = is_file_buffer and vim.fs.dirname(buffer_name) or vim.fn.getcwd()
    local toplevel_output, error_message = git(start_directory, { "rev-parse", "--show-toplevel" })
    if not toplevel_output then return nil, error_message end
    return vim.trim(toplevel_output)
end

-- Parses `git diff --unified=0 --no-prefix` into one entry per hunk, with the
-- path relative to the root and the hunk's lines in the working tree. Header
-- lines are only read between `diff --git` and the first `@@`: a removed line
-- `-- comment` reads as `--- comment` in the diff, like a header.
local function parse_diff_hunks(diff_output)
    local hunk_entries = {}
    local old_path, new_path, in_file_header, current_hunk
    for diff_line in vim.gsplit(diff_output, "\n", { plain = true }) do
        if diff_line:find("^diff %-%-git ") then
            in_file_header, old_path, new_path, current_hunk = true, nil, nil, nil
        elseif in_file_header and diff_line:find("^%-%-%- ") then
            old_path = diff_line:sub(5)
        elseif in_file_header and diff_line:find("^%+%+%+ ") then
            new_path = diff_line:sub(5)
            -- A deleted file gets one entry, not one per hunk: its lines are
            -- gone, so there's nothing to jump to.
            if new_path == "/dev/null" then
                -- `deleted` tells front ends there's no file to open; the
                -- text alone won't do, as a note replaces it.
                table.insert(
                    hunk_entries,
                    { path = old_path, lnum = 1, end_lnum = 1, text = "deleted file", deleted = true }
                )
            end
        elseif diff_line:find("^@@ ") then
            in_file_header = false
            if new_path ~= "/dev/null" then
                -- `@@ -old[,count] +new[,count] @@`; a missing count means 1.
                local new_start, new_count = diff_line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
                new_start, new_count = tonumber(new_start) or 1, tonumber(new_count) or 1
                -- Only removals: the new side is empty and `new_start` is the
                -- line before the gap, 0 at the top of the file.
                local first_line = math.max(new_start, 1)
                local last_line = new_count == 0 and first_line or new_start + new_count - 1
                current_hunk = {
                    path = new_path,
                    lnum = first_line,
                    end_lnum = last_line,
                    -- For the inline review layout (mark_buffer): the hunk's
                    -- lines as git gives them, the removed ones in full.
                    new_start = new_start,
                    added_count = new_count,
                    removed_lines = {},
                }
                table.insert(hunk_entries, current_hunk)
            end
        elseif current_hunk and not in_file_header then
            -- Keep the removed lines as they were, for the diff marks, and
            -- the first added line for the entry's text (without a note).
            local line_sign, line_content = diff_line:sub(1, 1), diff_line:sub(2)
            if line_sign == "+" and not current_hunk.text then
                current_hunk.text = vim.trim(line_content)
            elseif line_sign == "-" then
                table.insert(current_hunk.removed_lines, line_content)
            end
        end
    end
    for _, hunk_entry in ipairs(hunk_entries) do
        -- The entry shows the first added line, else the first removed one.
        local first_removed = hunk_entry.removed_lines and hunk_entry.removed_lines[1]
        hunk_entry.text = hunk_entry.text or (first_removed and ("removed: " .. vim.trim(first_removed))) or ""
    end
    return hunk_entries
end

-- Reads the locations at the start of a note item's text: one or more,
-- separated by commas, each `path:line`, `path:first-last`, or just a line or
-- range for the file of the heading above (`heading_path`). In backticks a
-- path may hold spaces; without them it ends at a space or comma. Returns the
-- list of { path, first_line, last_line } and the text after the last one.
-- E.g. "`70`, `TODO.md:84-86` — why" gives two locations and "— why".
local function parse_note_locations(item_text, heading_path)
    local note_locations, remaining_text = {}, item_text
    while true do
        local location_text, text_after = remaining_text:match("^`([^`]+)`(.*)$")
        if not location_text then
            location_text, text_after = remaining_text:match("^([^%s,`]+)(.*)$")
        end
        if not location_text then break end
        local location_path, first_line, last_line = location_text:match("^(.+):(%d+)%-?(%d*)$")
        if not location_path then
            first_line, last_line = location_text:match("^(%d+)%-?(%d*)$")
            location_path = first_line and heading_path
        end
        -- Not a location: the text starts here (or the item is no note).
        if not (location_path and first_line) then break end
        first_line = tonumber(first_line)
        table.insert(note_locations, {
            path = location_path,
            first_line = first_line,
            last_line = tonumber(last_line) or first_line,
        })
        remaining_text = text_after
        -- A comma means another location follows; else the text starts.
        local text_after_comma = remaining_text:match("^%s*,%s*(.*)$")
        if not text_after_comma then break end
        remaining_text = text_after_comma
    end
    return note_locations, remaining_text
end

-- Reads the notes file. Returns a table from path to a list of
-- { lnum, end_lnum, text, new }, and the title, nil without one.
local function read_notes(repository_root)
    local notes_by_path, notes_title, heading_path = {}, nil, nil
    local notes_handle = io.open(repository_root .. "/" .. M.notes_file, "r")
    if not notes_handle then return notes_by_path, nil end

    -- A list item may wrap over several lines, as markdown formatters (rumdl
    -- here) rewrap long items at 80 columns. Reading line by line cut every
    -- note off at its first line end, so the item's lines are collected
    -- first and parsed as one text once the item ends.
    local item_text_parts, item_heading_path = nil, nil

    -- Parses the collected item, if any: it starts with its locations, and
    -- the same text becomes the note of each.
    local function finish_item()
        if not item_text_parts then return end
        local item_text = table.concat(item_text_parts, " ")
        item_text_parts = nil
        local note_locations, note_text = parse_note_locations(item_text, item_heading_path)
        if #note_locations == 0 then return end
        -- Drop the separator before the why: a colon, an em or en dash, or
        -- a hyphen.
        note_text = vim.trim(note_text):gsub("^:%s*", ""):gsub("^—%s*", ""):gsub("^–%s*", ""):gsub("^%-%s*", "")
        -- "· new" at the end marks a change from this round. It's dropped
        -- from the text: the list shows it by grouping.
        local text_without_mark = note_text:gsub("%s*·%s*new%s*$", "")
        for _, note_location in ipairs(note_locations) do
            notes_by_path[note_location.path] = notes_by_path[note_location.path] or {}
            table.insert(notes_by_path[note_location.path], {
                lnum = note_location.first_line,
                end_lnum = note_location.last_line,
                text = text_without_mark,
                new = text_without_mark ~= note_text,
                used = false,
            })
        end
    end

    for notes_line in notes_handle:lines() do
        local file_heading = notes_line:match("^##%s+(.-)%s*$")
        -- The first `#` heading is the title; `##` doesn't match `^#%s`.
        local title_heading = notes_line:match("^#%s+(.-)%s*$")
        -- A list item: `-`, `*` or `+`, indented or not.
        local item_start_text = notes_line:match("^%s*[-*+]%s+(.*)$")
        -- An indented line that isn't an item continues the item above it.
        local continuation_text = notes_line:match("^%s+(%S.*)$")
        if file_heading then
            finish_item()
            -- Backticks around the path are optional.
            heading_path = file_heading:gsub("^`(.*)`$", "%1")
        elseif title_heading then
            finish_item()
            notes_title = notes_title or title_heading
        elseif item_start_text then
            finish_item()
            item_text_parts, item_heading_path = { item_start_text }, heading_path
        elseif continuation_text and item_text_parts then
            table.insert(item_text_parts, vim.trim(continuation_text))
        else
            -- A blank line or a paragraph ends the item.
            finish_item()
        end
    end
    finish_item()
    notes_handle:close()
    return notes_by_path, notes_title
end

-- Collects the unstaged changes with their notes, for both front ends: the
-- quickfix list below and the trouble.nvim source in
-- `lua/trouble/sources/agent_review.lua`. Returns nil and an error message
-- outside a repository or when git fails, else a table:
--   repository_root  absolute path
--   title            the notes' title, nil without one
--   entries          { path, lnum, end_lnum, text, new }, sorted new first,
--                    then by path and line; end_lnum is math.huge for a new
--                    file, which is one change as a whole; diff hunks also
--                    carry new_start, added_count and removed_lines (git's
--                    view of the hunk), for the diff marks
--   unmatched_count  notes that match no unstaged change
-- Entry texts carry no "[new]" mark: each front end shows `new` its own way.
function M.collect()
    local repository_root, root_error = find_repository_root()
    if not repository_root then return nil, "Not in a git repository: " .. root_error end

    local diff_output, diff_error =
        git(repository_root, { "diff", "--unified=0", "--no-color", "--no-ext-diff", "--no-prefix" })
    -- -z separates paths with NUL, so names with spaces or newlines come
    -- through whole.
    local untracked_output, untracked_error =
        git(repository_root, { "ls-files", "--others", "--exclude-standard", "-z" })
    if not diff_output or not untracked_output then return nil, "git failed: " .. (diff_error or untracked_error) end

    local change_entries = parse_diff_hunks(diff_output)
    for untracked_path in vim.gsplit(untracked_output, "\0", { plain = true, trimempty = true }) do
        -- Listed by hand in case the global ignore file isn't set up.
        if untracked_path ~= M.notes_file then
            -- A new file is one change: any note in it belongs to this entry.
            table.insert(change_entries, { path = untracked_path, lnum = 1, end_lnum = math.huge, text = "new file" })
        end
    end
    -- Each note goes to every hunk its lines overlap, so a note for a range
    -- that git splits into several hunks shows on each; several notes for one
    -- hunk are joined. A note matching no hunk is about a change that's been
    -- staged or reset since, or one whose lines moved, and is left out.
    local notes_by_path, notes_title = read_notes(repository_root)
    for _, change_entry in ipairs(change_entries) do
        local matching_texts = {}
        for _, note in ipairs(notes_by_path[change_entry.path] or {}) do
            if note.lnum <= change_entry.end_lnum and note.end_lnum >= change_entry.lnum then
                table.insert(matching_texts, note.text)
                note.used = true
                change_entry.new = change_entry.new or note.new
            end
        end
        if #matching_texts > 0 then change_entry.text = table.concat(matching_texts, "; ") end
    end

    -- This round's changes first, so a new round starts with what I haven't
    -- seen; within each group by path, then by line, as git sorts (untracked
    -- files came last, after the diff's own order).
    table.sort(change_entries, function(left_entry, right_entry)
        if (left_entry.new or false) ~= (right_entry.new or false) then return left_entry.new == true end
        if left_entry.path ~= right_entry.path then return left_entry.path < right_entry.path end
        return left_entry.lnum < right_entry.lnum
    end)
    local unmatched_count = 0
    for _, path_notes in pairs(notes_by_path) do
        for _, note in ipairs(path_notes) do
            if not note.used then unmatched_count = unmatched_count + 1 end
        end
    end
    return {
        repository_root = repository_root,
        title = notes_title,
        entries = change_entries,
        unmatched_count = unmatched_count,
    }
end

-- Warns about notes that match no unstaged change: staged or reset since, or
-- their lines moved. Shared by both front ends.
function M.warn_unmatched(changes)
    if changes.unmatched_count > 0 then
        vim.notify(
            ("%d note(s) in %s match no unstaged change"):format(changes.unmatched_count, M.notes_file),
            vim.log.levels.WARN
        )
    end
end

-- Fills the quickfix list with the unstaged changes, as a new list so
-- `:colder` still reaches the one before, and opens it. `<leader>ar` shows
-- them in trouble.nvim instead now; this stays for `:cdo` and the like.
function M.to_quickfix()
    local changes, collect_error = M.collect()
    if not changes then
        vim.notify(collect_error, vim.log.levels.ERROR)
        return
    end
    local repository_root = changes.repository_root

    if #changes.entries == 0 then
        vim.notify("No unstaged changes in " .. repository_root)
        return
    end

    local quickfix_items = {}
    for _, change_entry in ipairs(changes.entries) do
        table.insert(quickfix_items, {
            filename = repository_root .. "/" .. change_entry.path,
            lnum = change_entry.lnum,
            -- Only for a hunk with real lines; quickfix shows it as a range.
            end_lnum = change_entry.end_lnum ~= math.huge and change_entry.end_lnum or nil,
            -- Quickfix has no other way to show this round's changes than the
            -- sort, so mark them in the text.
            text = (change_entry.new and "[new] " or "") .. change_entry.text,
            -- Lets the cursor sync treat a new file as one change.
            user_data = change_entry.end_lnum == math.huge and { whole_file = true } or nil,
        })
    end
    -- The notes' title names the list, so :chistory tells rounds of
    -- different changes apart.
    vim.fn.setqflist({}, " ", { title = changes.title or "Unstaged changes", items = quickfix_items })
    -- The list just made is the current one; remember it, and sync on every
    -- cursor move. The group is cleared on each fill, so there's one autocmd.
    agent_list_id = vim.fn.getqflist({ id = 0 }).id
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
        group = vim.api.nvim_create_augroup("agent_review_quickfix", { clear = true }),
        callback = select_entry_under_cursor,
        desc = "Make the agent change under the cursor the current quickfix entry",
    })
    M.warn_unmatched(changes)
    vim.cmd("copen")
end

-- Review display: while reviewing (the trouble list is open), each change
-- shows in the files themselves, in one of two layouts, both plain nvim:
--   inline        removed lines as virtual lines where they were
--                 (DiffDelete), added lines DiffAdd, lines that replace
--                 removed ones DiffChange; every hunk at once, like
--                 gitsigns' inline preview
--   side_by_side  the index version (what's staged, so the file before the
--                 agent's changes) in a window on the left, in nvim's diff
--                 mode against the file in view, trouble's preview included
-- `vim.g.agent_review_layout` sets the layout a review starts in ("inline"
-- unless set); M.toggle_review_layout switches, also during a review.
local diff_marks_namespace = vim.api.nvim_create_namespace("agent_review_diff")
local review = {
    -- The changes on display, from the last collect; nil while no review is on.
    changes = nil,
    -- "inline" or "side_by_side".
    layout = nil,
    -- side_by_side: the window and scratch buffer with the index version,
    -- and the window it's diffed against.
    index_window = nil,
    index_buffer = nil,
    diffed_window = nil,
}

-- Virtual text shows a tab as a single cell, so expand tabs to the buffer's
-- tabstop to keep removed lines aligned with the real ones.
local function expand_tabs(line_content, buffer_number)
    return (line_content:gsub("\t", string.rep(" ", vim.bo[buffer_number].tabstop)))
end

-- Inline layout: puts the marks for one buffer, replacing any it had. Line
-- numbers come from the last collect; marks then move with edits like any
-- extmark.
local function mark_buffer(buffer_number)
    if not review.changes or not vim.api.nvim_buf_is_loaded(buffer_number) then return end
    vim.api.nvim_buf_clear_namespace(buffer_number, diff_marks_namespace, 0, -1)
    local buffer_path = vim.api.nvim_buf_get_name(buffer_number)
    local line_count = vim.api.nvim_buf_line_count(buffer_number)
    for _, change_entry in ipairs(review.changes.entries) do
        -- Only diff hunks carry removed_lines; new and deleted files don't.
        local entry_path = review.changes.repository_root .. "/" .. change_entry.path
        if change_entry.removed_lines and entry_path == buffer_path then
            local has_removed = #change_entry.removed_lines > 0
            -- Added lines: DiffChange when they replace removed ones.
            local added_highlight = has_removed and "DiffChange" or "DiffAdd"
            for added_line = change_entry.new_start, change_entry.new_start + change_entry.added_count - 1 do
                if added_line >= 1 and added_line <= line_count then
                    vim.api.nvim_buf_set_extmark(buffer_number, diff_marks_namespace, added_line - 1, 0, {
                        line_hl_group = added_highlight,
                    })
                end
            end
            if has_removed then
                local virtual_lines = {}
                for _, removed_line in ipairs(change_entry.removed_lines) do
                    table.insert(virtual_lines, { { expand_tabs(removed_line, buffer_number), "DiffDelete" } })
                end
                -- Above the lines that replace them; for a pure removal git's
                -- new_start is the line before the gap, so below that one, or
                -- above line 1 when the gap is at the top.
                local anchor_line, above
                if change_entry.added_count > 0 then
                    anchor_line, above = change_entry.new_start, true
                elseif change_entry.new_start == 0 then
                    anchor_line, above = 1, true
                else
                    anchor_line, above = change_entry.new_start, false
                end
                anchor_line = math.min(math.max(anchor_line, 1), line_count)
                vim.api.nvim_buf_set_extmark(buffer_number, diff_marks_namespace, anchor_line - 1, 0, {
                    virt_lines = virtual_lines,
                    virt_lines_above = above,
                })
            end
        end
    end
end

local function clear_all_marks()
    for _, buffer_number in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buffer_number) then
            vim.api.nvim_buf_clear_namespace(buffer_number, diff_marks_namespace, 0, -1)
        end
    end
end

local function is_valid_window(window) return window ~= nil and vim.api.nvim_win_is_valid(window) end

-- A window showing a file, not a float (trouble's preview is passed in
-- explicitly) and not our index window.
local function is_file_window(window)
    if not is_valid_window(window) or window == review.index_window then return false end
    if vim.api.nvim_win_get_config(window).relative ~= "" then return false end
    local buffer_number = vim.api.nvim_win_get_buf(window)
    return vim.bo[buffer_number].buftype == "" and vim.api.nvim_buf_get_name(buffer_number) ~= ""
end

-- The window the review shows a file in: the current one if it holds a
-- file, else the first in the tab page that does (from the trouble list,
-- the one it jumps into).
local function find_main_window()
    local current_window = vim.api.nvim_get_current_win()
    if is_file_window(current_window) then return current_window end
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_file_window(window) then return window end
    end
end

-- Side-by-side layout: opens the index window left of the main window, if
-- it isn't open. Done before trouble's preview opens where possible: the
-- preview is a float sized to the main window when it opens.
local function ensure_index_window()
    if is_valid_window(review.index_window) then return true end
    local main_window = find_main_window()
    if not main_window then return false end
    if not (review.index_buffer and vim.api.nvim_buf_is_valid(review.index_buffer)) then
        review.index_buffer = vim.api.nvim_create_buf(false, true)
        vim.bo[review.index_buffer].bufhidden = "hide"
    end
    review.index_window = vim.api.nvim_open_win(review.index_buffer, false, { split = "left", win = main_window })
    return true
end

local function stop_side_by_side()
    if is_valid_window(review.diffed_window) then
        vim.api.nvim_win_call(review.diffed_window, function() vim.cmd("diffoff") end)
    end
    if is_valid_window(review.index_window) then vim.api.nvim_win_close(review.index_window, true) end
    if review.index_buffer and vim.api.nvim_buf_is_valid(review.index_buffer) then
        vim.api.nvim_buf_delete(review.index_buffer, { force = true })
    end
    review.index_window, review.index_buffer, review.diffed_window = nil, nil, nil
end

-- Side-by-side layout: shows the index version of the file in
-- `target_window` in the index window, and diffs the two. `target_window`
-- may be trouble's preview float; without one, the window diffed last if
-- it's still there (a refresh), else the main window (the preview closed).
-- Does nothing in the inline layout or outside a review.
function M.diff_side_by_side(target_window)
    if not review.changes or review.layout ~= "side_by_side" then return end
    if not is_valid_window(target_window) then target_window = nil end
    if not target_window and is_valid_window(review.diffed_window) then target_window = review.diffed_window end
    if not target_window then
        local main_window = find_main_window()
        target_window = main_window
        -- A float laid over the main window (trouble's preview) is what's
        -- on screen there, so diff that one.
        for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local window_config = vim.api.nvim_win_get_config(window)
            if window_config.relative == "win" and window_config.win == main_window then
                local float_buffer = vim.api.nvim_win_get_buf(window)
                if vim.bo[float_buffer].buftype == "" and vim.api.nvim_buf_get_name(float_buffer) ~= "" then
                    target_window = window
                end
            end
        end
    end
    if not is_valid_window(target_window) or not ensure_index_window() then return end
    local buffer_number = vim.api.nvim_win_get_buf(target_window)
    local file_path = vim.api.nvim_buf_get_name(buffer_number)
    local relative_path = vim.fs.relpath(review.changes.repository_root, file_path)
    if vim.bo[buffer_number].buftype ~= "" or not relative_path then return end

    -- `:path` is the index's version. A file git doesn't track yet has none:
    -- the left side stays empty and the whole file shows as added.
    local index_content = git(review.changes.repository_root, { "show", ":" .. relative_path }) or ""
    local index_lines = vim.split(index_content, "\n", { plain = true })
    if index_lines[#index_lines] == "" then table.remove(index_lines) end
    vim.bo[review.index_buffer].modifiable = true
    vim.api.nvim_buf_set_lines(review.index_buffer, 0, -1, false, index_lines)
    vim.bo[review.index_buffer].modifiable = false
    vim.bo[review.index_buffer].filetype = vim.bo[buffer_number].filetype
    -- Named after the file, so the window says what it shows; pcall as a name
    -- can be taken by an earlier review's buffer not yet wiped.
    pcall(vim.api.nvim_buf_set_name, review.index_buffer, "index: " .. relative_path)

    -- One pair at a time: the previous partner leaves diff mode.
    if review.diffed_window ~= target_window and is_valid_window(review.diffed_window) then
        vim.api.nvim_win_call(review.diffed_window, function() vim.cmd("diffoff") end)
    end
    vim.api.nvim_win_call(review.index_window, function() vim.cmd("diffthis") end)
    vim.api.nvim_win_call(target_window, function() vim.cmd("diffthis") end)
    review.diffed_window = target_window
end

-- Puts the current layout on screen and takes the other one down.
local function apply_layout()
    if review.layout == "inline" then
        stop_side_by_side()
        for _, buffer_number in ipairs(vim.api.nvim_list_bufs()) do
            mark_buffer(buffer_number)
        end
    else
        clear_all_marks()
        M.diff_side_by_side()
    end
end

-- Starts a review, or updates the one on: shows `changes` (from M.collect)
-- in the current layout. Called on every refresh, which redraws from the new
-- diff (after staging a hunk, the index side changes too).
function M.review_update(changes)
    if not review.changes then
        review.layout = vim.g.agent_review_layout == "side_by_side" and "side_by_side" or "inline"
    end
    review.changes = changes
    local review_group = vim.api.nvim_create_augroup("agent_review_display", { clear = true })
    vim.api.nvim_create_autocmd("BufReadPost", {
        group = review_group,
        callback = function(autocmd_event)
            if review.layout == "inline" then mark_buffer(autocmd_event.buf) end
        end,
        desc = "Show the agent's changes in files opened during the review",
    })
    vim.api.nvim_create_autocmd("BufWinEnter", {
        group = review_group,
        callback = function()
            local current_window = vim.api.nvim_get_current_win()
            if review.layout == "side_by_side" and is_file_window(current_window) then
                M.diff_side_by_side(current_window)
            end
        end,
        desc = "Diff the file that comes into view against the index",
    })
    apply_layout()
end

-- Ends the review: marks, index window and diff mode go.
function M.review_stop()
    review.changes = nil
    vim.api.nvim_create_augroup("agent_review_display", { clear = true })
    clear_all_marks()
    stop_side_by_side()
end

-- Switches between inline and side by side, for the review on and the next.
-- Known issue: with trouble's preview open, switching to side by side leaves
-- the preview float overlapping the new index window (see README.md). A fix
-- would close the preview before opening the index window, so trouble
-- reopens it at the new size, which needs a hook into trouble from here.
function M.toggle_review_layout()
    local current_layout = review.layout or vim.g.agent_review_layout or "inline"
    local new_layout = current_layout == "side_by_side" and "inline" or "side_by_side"
    vim.g.agent_review_layout = new_layout
    if review.changes then
        review.layout = new_layout
        apply_layout()
    end
    vim.notify("Agent review: " .. new_layout:gsub("_", " "))
end

-- Watching the notes file: the agent rewrites it at the end of every turn,
-- so a change to it means a round is done and the list is worth refreshing,
-- even while I stay in nvim and nothing else fires (no focus change, and
-- gitsigns sees only loaded buffers). Watching every file the agent writes
-- instead would refresh mid-turn, with hunks whose notes aren't written yet.
local notes_watch = { handle = nil, timer = nil, repository_root = nil }

-- How long to wait after the last change before acting: one rewrite can
-- fire several events (truncate, write, rename).
local notes_debounce_ms = 200

-- Starts watching the notes file in `repository_root`, or moves the watch
-- there. On a change it reloads open buffers the agent changed
-- (`:checktime`) and fires `User AgentReviewNotesChanged`, which the trouble
-- mode refreshes on. Watches the directory rather than the file: an editor
-- or tool that writes a new file and renames it over the old one would end a
-- watch on the file itself. libuv watches don't recurse, so this only sees
-- the repository root's own entries; the callback filters for the notes.
function M.watch_notes(repository_root)
    if notes_watch.handle and notes_watch.repository_root == repository_root then return end
    M.unwatch_notes()
    local watch_handle = vim.uv.new_fs_event()
    local debounce_timer = vim.uv.new_timer()
    if not watch_handle or not debounce_timer then return end
    local watch_ok = watch_handle:start(repository_root, {}, function(watch_error, changed_name)
        if watch_error or changed_name ~= M.notes_file then return end
        -- Restarting the timer on each event acts once the burst is over;
        -- the work goes to the main loop, as libuv callbacks may not call
        -- most of the nvim API.
        debounce_timer:stop()
        debounce_timer:start(
            notes_debounce_ms,
            0,
            vim.schedule_wrap(function()
                if vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
                vim.api.nvim_exec_autocmds("User", { pattern = "AgentReviewNotesChanged" })
            end)
        )
    end)
    if not watch_ok then
        watch_handle:close()
        debounce_timer:close()
        return
    end
    notes_watch.handle, notes_watch.timer, notes_watch.repository_root = watch_handle, debounce_timer, repository_root
end

-- Stops the watch, if any.
function M.unwatch_notes()
    if notes_watch.handle then
        notes_watch.handle:stop()
        notes_watch.handle:close()
    end
    if notes_watch.timer then
        notes_watch.timer:stop()
        notes_watch.timer:close()
    end
    notes_watch.handle, notes_watch.timer, notes_watch.repository_root = nil, nil, nil
end

return M
