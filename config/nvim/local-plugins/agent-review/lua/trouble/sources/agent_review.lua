-- trouble.nvim source for agent-review: `:Trouble agent_review`. An extension
-- of trouble that this plugin ships, in the shape of trouble's own sources:
-- `config` adds the `agent_review` mode, `get` hands trouble the items,
-- `preview` and `setup` are hooks trouble calls. trouble finds it by its path
-- on the runtimepath: when a mode is first asked for, it registers every
-- `lua/trouble/sources/<name>.lua` of the loaded plugins, its own and this
-- one (`require("trouble.sources").load`). So this plugin has to be loaded
-- before `:Trouble agent_review` runs, which its keys take care of. The data
-- and the display in the files come from `agent_review` (`collect`,
-- `review_update`), which knows nothing of trouble; this file only adapts it.
--
-- Why trouble over the quickfix list for this: entries grouped under their
-- file, the line range in front and the agent's note after it with the rest
-- of the width, and the list refreshes itself as hunks get staged or reset.

local Item = require("trouble.item")

local M = {}

-- Section names for the `round` group. Fields are strings so trouble can show
-- them; the sort uses `new` (a boolean) to put this round first.
local this_round_label = "This round"
local earlier_label = "Earlier rounds"

M.config = {
    modes = {
        agent_review = {
            desc = "Unstaged changes, with the agent's notes",
            source = "agent_review",
            -- Refresh on what changes the diff or the notes: a save, gitsigns
            -- staging or resetting a hunk (it fires GitSignsUpdate after each
            -- change to its signs), and coming back from the terminal where
            -- the agent ran. `r` refreshes by hand.
            events = {
                "BufWritePost",
                "FocusGained",
                { event = "User", pattern = "GitSignsUpdate" },
            },
            -- This round's changes and the earlier ones apart, each grouped by
            -- file: what I haven't seen comes first.
            groups = {
                { "round", format = "{round}" },
                { "filename", format = "{file_icon} {filename} {count}" },
            },
            sort = { "new", "filename", "pos" },
            -- Line range first, a fixed-width column, so the notes line up
            -- and get the rest of the line.
            format = "{lines} {text}",
            -- Notes run long: wrap them at word boundaries instead of cutting
            -- them off, and indent the continuation lines (breakindent) so
            -- the tree stays readable.
            win = { wo = { wrap = true, linebreak = true, breakindent = true } },
            formatters = {
                -- "7-18", "7", or "file" for a new file (one change as a whole),
                -- padded so the notes start in one column.
                lines = function(format_context)
                    local change_item = format_context.item
                    local lines_text
                    if change_item.whole_file then
                        lines_text = "file"
                    elseif change_item.end_pos[1] > change_item.pos[1] then
                        lines_text = change_item.pos[1] .. "-" .. change_item.end_pos[1]
                    else
                        lines_text = tostring(change_item.pos[1])
                    end
                    return { text = ("%-9s"):format(lines_text), hl = "TroublePos" }
                end,
            },
        },
    },
}

-- Buffers during a review. The preview loads files into real buffers (for
-- highlighting and gitsigns), and trouble lists them, so they'd pile up
-- among my buffers. Files I only previewed get unloaded and unlisted again,
-- back to how bufadd leaves them, once the preview moves to another file or
-- the list closes. Kept: buffers loaded before the review, ones I entered
-- (jumped to), and modified or visible ones.
local review_buffers = {
    -- Whether a review is on; set by the first get(), cleared on close.
    active = false,
    loaded_before = {},
    preview_loaded = {},
    entered = {},
}

local function release_preview_buffers(keep_buffer)
    for buffer_number in pairs(review_buffers.preview_loaded) do
        if not vim.api.nvim_buf_is_valid(buffer_number) or review_buffers.entered[buffer_number] then
            -- Gone, or mine now: stop tracking it.
            review_buffers.preview_loaded[buffer_number] = nil
        elseif
            buffer_number ~= keep_buffer
            and not vim.bo[buffer_number].modified
            and #vim.fn.win_findbuf(buffer_number) == 0
        then
            vim.bo[buffer_number].buflisted = false
            -- Unloaded, not deleted: items keep the buffer number for follow.
            vim.cmd("bunload " .. buffer_number)
            review_buffers.preview_loaded[buffer_number] = nil
        end
        -- Else (previewed now, modified or visible): checked again next time.
    end
end

local function start_review_buffers()
    review_buffers.active = true
    review_buffers.loaded_before, review_buffers.preview_loaded, review_buffers.entered = {}, {}, {}
    for _, buffer_number in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buffer_number) then review_buffers.loaded_before[buffer_number] = true end
    end
    -- I went into the file myself when it's entered in a normal window:
    -- loading it for the preview fires BufEnter too, but in nvim's hidden
    -- autocmd window (win_gettype "autocmd"), and the preview is a float.
    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("agent_review_trouble_buffers", { clear = true }),
        callback = function(autocmd_event)
            local is_normal_window = vim.fn.win_gettype() == "" and vim.api.nvim_win_get_config(0).relative == ""
            if is_normal_window then review_buffers.entered[autocmd_event.buf] = true end
        end,
        desc = "Keep files entered during the agent review loaded",
    })
end

local function stop_review_buffers()
    review_buffers.active = false
    vim.api.nvim_create_augroup("agent_review_trouble_buffers", { clear = true })
    release_preview_buffers(nil)
end

-- Called once, when trouble registers the source. The review display
-- (agent_review.review_update) and the buffer bookkeeping belong to the
-- open list: they end when its trouble window closes. Any other window
-- closing may be the preview float, whose diff partner then falls back to
-- the main window. Scheduled, as the view still counts as open while its
-- window is closing.
function M.setup()
    vim.api.nvim_create_autocmd("WinClosed", {
        group = vim.api.nvim_create_augroup("agent_review_trouble", { clear = true }),
        callback = function()
            vim.schedule(function()
                if not review_buffers.active then return end
                if require("trouble").is_open("agent_review") then
                    require("agent_review").diff_side_by_side()
                else
                    require("agent_review").review_stop()
                    stop_review_buffers()
                end
            end)
        end,
        desc = "End the agent review when its trouble list closes",
    })
end

-- Called by trouble each time it previews an item, after putting its buffer
-- in the preview window: remember a buffer the preview loaded, let go of the
-- previous one, and diff this one against the index in the side-by-side
-- layout.
function M.preview(_, preview_state)
    local preview_buffer = preview_state.buf
    if not review_buffers.loaded_before[preview_buffer] and not review_buffers.entered[preview_buffer] then
        review_buffers.preview_loaded[preview_buffer] = true
    end
    release_preview_buffers(preview_buffer)
    require("agent_review").diff_side_by_side(preview_state.win)
end

-- Called by trouble on open and on every refresh event; `items_callback`
-- takes the list.
function M.get(items_callback)
    local agent_review = require("agent_review")
    local changes, collect_error = agent_review.collect()
    if not changes then
        vim.notify(collect_error, vim.log.levels.ERROR)
        items_callback({})
        return
    end
    if not review_buffers.active then start_review_buffers() end
    -- Show the changes in the files, redrawn from this refresh's diff.
    agent_review.review_update(changes)
    local change_items = {}
    for _, change_entry in ipairs(changes.entries) do
        local is_whole_file = change_entry.end_lnum == math.huge
        local last_line = is_whole_file and change_entry.lnum or change_entry.end_lnum
        local change_path = changes.repository_root .. "/" .. change_entry.path
        table.insert(
            change_items,
            Item.new({
                source = "agent_review",
                filename = change_path,
                -- trouble's follow (the list's cursor tracks the change under
                -- the cursor in the file) only matches items by buffer number.
                -- bufadd gives the file's buffer, or makes an unloaded,
                -- unlisted one that :edit reuses later; skipped for a deleted
                -- file, which has none to open.
                buf = not change_entry.deleted and vim.fn.bufadd(change_path) or nil,
                -- trouble's positions are (1,0)-indexed: line, column.
                pos = { change_entry.lnum, 0 },
                end_pos = { last_line, 0 },
                text = change_entry.text,
                new = change_entry.new or false,
                round = change_entry.new and this_round_label or earlier_label,
                whole_file = is_whole_file,
            })
        )
    end
    Item.add_id(change_items)
    items_callback(change_items)
end

return M
