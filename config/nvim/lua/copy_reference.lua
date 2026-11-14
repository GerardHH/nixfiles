-- Copy a reference to the code under the cursor, `path/from/root/file.lua:42`, or
-- `file.lua:42-58` for a visual range, to the clipboard. For pointing an agent (or a
-- colleague in chat) at code: any agent and any chat take plain text, unlike
-- claudecode.nvim's @-mentions, which only reach Claude.

local M = {}

-- The directory the path is relative to: the git root, as that's what agents and git
-- diffs use, else the cwd for files outside a repository.
local function reference_root(buffer_number) return vim.fs.root(buffer_number, ".git") or vim.fn.getcwd() end

-- Builds "path:first" or "path:first-last" and puts it in the `+` register, which
-- options/clipboard.lua routes to the system clipboard (or OSC 52 in a container).
local function copy_lines(first_line, last_line)
    local buffer_number = vim.api.nvim_get_current_buf()
    local absolute_path = vim.api.nvim_buf_get_name(buffer_number)
    if absolute_path == "" then
        vim.notify("Copy reference: buffer has no file", vim.log.levels.WARN)
        return
    end
    -- relpath gives nil for a file outside the root (e.g. a cwd elsewhere); keep the
    -- absolute path then, which still works as a reference.
    local reference_path = vim.fs.relpath(reference_root(buffer_number), absolute_path) or absolute_path

    local reference = reference_path .. ":" .. first_line
    if last_line ~= first_line then reference = reference .. "-" .. last_line end
    vim.fn.setreg("+", reference)
    vim.notify("Copied " .. reference)
end

-- Normal mode: the cursor's line.
function M.copy_cursor()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    copy_lines(cursor_line, cursor_line)
end

-- Visual mode: the selected lines, in either direction. `v` is the other end of the
-- selection while still in visual mode; leave visual mode afterwards, as `y` does.
function M.copy_selection()
    local anchor_line = vim.fn.line("v")
    local cursor_line = vim.fn.line(".")
    copy_lines(math.min(anchor_line, cursor_line), math.max(anchor_line, cursor_line))
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end

return M
