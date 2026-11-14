-- Reviews an agent's changes from the quickfix list. Fills it with the
-- changes in the working tree that aren't staged yet: one entry per hunk of
-- `git diff` (working tree against the index), one per untracked file.
-- Staging is how a change gets accepted, so the list is what's left to
-- review. Built from git alone, so it works the same for any agent.
--
-- While the list exists, moving the cursor onto one of its changes in a
-- buffer makes that entry the current one, so `:cnext` and the quickfix
-- window carry on from where I am, not from where I last jumped from the list.
--
-- An agent explains its changes in a Markdown notes file at the repository
-- root, rewritten every turn to describe what's still unstaged:
--
--     # nvim: Title of the change, as a commit subject
--
--     Free text: a summary, and what this round changed.
--
--     ## config/nvim/lua/qf_agent_changes.lua
--
--     - `7-18` — why, in one sentence · new
--     - `92` — why
--
-- A `## path` heading names a file, from the repository root; the items under
-- it give lines in the working tree, one line or `first-last`. An item may
-- also carry its own path, "- `path:7-18` — why", anywhere in the file.
-- "· new" marks what changed this round. A note becomes the text of each entry
-- whose hunk it overlaps; without one, the entry shows the hunk's first line.
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
                table.insert(hunk_entries, { path = old_path, lnum = 1, end_lnum = 1, text = "deleted file" })
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
                current_hunk = { path = new_path, lnum = first_line, end_lnum = last_line }
                table.insert(hunk_entries, current_hunk)
            end
        elseif current_hunk and not in_file_header then
            -- Remember the hunk's first added line and its first removed one;
            -- the entry shows the added one, else the removed one.
            local line_sign, line_content = diff_line:sub(1, 1), vim.trim(diff_line:sub(2))
            if line_sign == "+" and not current_hunk.text then
                current_hunk.text = line_content
            elseif line_sign == "-" and not current_hunk.removed then
                current_hunk.removed = line_content
            end
        end
    end
    for _, hunk_entry in ipairs(hunk_entries) do
        hunk_entry.text = hunk_entry.text or (hunk_entry.removed and ("removed: " .. hunk_entry.removed)) or ""
        hunk_entry.removed = nil
    end
    return hunk_entries
end

-- Reads the notes file. Returns a table from path to a list of
-- { lnum, end_lnum, text, new }, and the title, nil without one.
local function read_notes(repository_root)
    local notes_by_path, notes_title, heading_path = {}, nil, nil
    local notes_handle = io.open(repository_root .. "/" .. M.notes_file, "r")
    if not notes_handle then return notes_by_path, nil end
    for notes_line in notes_handle:lines() do
        local file_heading = notes_line:match("^##%s+(.-)%s*$")
        -- The first `#` heading is the title; `##` doesn't match `^#%s`.
        local title_heading = notes_line:match("^#%s+(.-)%s*$")
        if file_heading then
            -- Backticks around the path are optional.
            heading_path = file_heading:gsub("^`(.*)`$", "%1")
        elseif title_heading then
            notes_title = notes_title or title_heading
        else
            -- A list item (`-`, `*` or `+`) with its own `path:line` or
            -- `path:first-last`. In backticks the path may hold spaces;
            -- without them it ends at the first one.
            local note_path, first_line, last_line, note_text =
                notes_line:match("^%s*[-*+]%s+`([^`]+):(%d+)%-?(%d*)`%s*(.*)$")
            if not note_path then
                note_path, first_line, last_line, note_text =
                    notes_line:match("^%s*[-*+]%s+([^%s`]+):(%d+)%-?(%d*)%s*(.*)$")
            end
            -- Else one with only `line` or `first-last`, for the file of the
            -- heading above it.
            if not note_path and heading_path then
                first_line, last_line, note_text = notes_line:match("^%s*[-*+]%s+`?(%d+)%-?(%d*)`?%s*(.*)$")
                if first_line then note_path = heading_path end
            end
            if note_path then
                -- Drop the separator before the why: a colon, an em or en
                -- dash, or a hyphen.
                note_text = note_text:gsub("^:%s*", ""):gsub("^—%s*", ""):gsub("^–%s*", ""):gsub("^%-%s*", "")
                -- "· new" at the end marks a change from this round.
                local text_without_mark = note_text:gsub("%s*·%s*new%s*$", "")
                first_line = tonumber(first_line)
                notes_by_path[note_path] = notes_by_path[note_path] or {}
                table.insert(notes_by_path[note_path], {
                    lnum = first_line,
                    end_lnum = tonumber(last_line) or first_line,
                    text = text_without_mark,
                    new = text_without_mark ~= note_text,
                    used = false,
                })
            end
        end
    end
    notes_handle:close()
    return notes_by_path, notes_title
end

-- Fills the quickfix list with the unstaged changes, as a new list so
-- `:colder` still reaches the one before, and opens it.
function M.to_quickfix()
    local repository_root, root_error = find_repository_root()
    if not repository_root then
        vim.notify("Not in a git repository: " .. root_error, vim.log.levels.ERROR)
        return
    end

    local diff_output, diff_error =
        git(repository_root, { "diff", "--unified=0", "--no-color", "--no-ext-diff", "--no-prefix" })
    -- -z separates paths with NUL, so names with spaces or newlines come
    -- through whole.
    local untracked_output, untracked_error =
        git(repository_root, { "ls-files", "--others", "--exclude-standard", "-z" })
    if not diff_output or not untracked_output then
        vim.notify("git failed: " .. (diff_error or untracked_error), vim.log.levels.ERROR)
        return
    end

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
        -- Marked in the list too, as the sort below is the only other sign.
        if change_entry.new then change_entry.text = "[new] " .. change_entry.text end
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

    if #change_entries == 0 then
        vim.notify("No unstaged changes in " .. repository_root)
        return
    end

    local quickfix_items = {}
    for _, change_entry in ipairs(change_entries) do
        table.insert(quickfix_items, {
            filename = repository_root .. "/" .. change_entry.path,
            lnum = change_entry.lnum,
            -- Only for a hunk with real lines; quickfix shows it as a range.
            end_lnum = change_entry.end_lnum ~= math.huge and change_entry.end_lnum or nil,
            text = change_entry.text,
            -- Lets the cursor sync treat a new file as one change.
            user_data = change_entry.end_lnum == math.huge and { whole_file = true } or nil,
        })
    end
    -- The notes' title names the list, so :chistory tells rounds of
    -- different changes apart.
    vim.fn.setqflist({}, " ", { title = notes_title or "Unstaged changes", items = quickfix_items })
    -- The list just made is the current one; remember it, and sync on every
    -- cursor move. The group is cleared on each fill, so there's one autocmd.
    agent_list_id = vim.fn.getqflist({ id = 0 }).id
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
        group = vim.api.nvim_create_augroup("qf_agent_changes", { clear = true }),
        callback = select_entry_under_cursor,
        desc = "Make the agent change under the cursor the current quickfix entry",
    })
    if unmatched_count > 0 then
        vim.notify(
            ("%d note(s) in %s match no unstaged change"):format(unmatched_count, M.notes_file),
            vim.log.levels.WARN
        )
    end
    vim.cmd("copen")
end

return M
