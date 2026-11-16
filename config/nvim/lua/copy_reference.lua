-- Copy a reference to the code under the cursor, `path/from/root/file.lua:42`, or
-- `file.lua:42-58` for a visual range, to the clipboard. For pointing an agent (or a
-- colleague in chat) at code: any agent and any chat take plain text, unlike
-- claudecode.nvim's @-mentions, which only reach Claude. Every function takes
-- `{ full_path = true }` for the absolute path instead, for a reader outside the
-- repository (another project's agent, a shell elsewhere).

local M = {}

-- The directory the path is relative to: the git root, as that's what agents and git
-- diffs use, else the cwd for files outside a repository.
local function reference_root(buffer_number) return vim.fs.root(buffer_number, ".git") or vim.fn.getcwd() end

-- The current buffer's path, relative to the reference root or absolute with
-- `full_path`; nil (after a warning) for a buffer without a file. Shared by the line
-- references and the file-only copy so both name a file the same way.
local function current_file_path(full_path)
    local buffer_number = vim.api.nvim_get_current_buf()
    local absolute_path = vim.api.nvim_buf_get_name(buffer_number)
    if absolute_path == "" then
        vim.notify("Copy reference: buffer has no file", vim.log.levels.WARN)
        return nil
    end
    if full_path then return absolute_path end
    -- relpath gives nil for a file outside the root (e.g. a cwd elsewhere); keep the
    -- absolute path then, which still works as a reference.
    return vim.fs.relpath(reference_root(buffer_number), absolute_path) or absolute_path
end

-- Puts the text in the `+` register, which options/clipboard.lua routes to the
-- system clipboard (or OSC 52 in a container), and says what was copied.
local function copy_text(reference)
    vim.fn.setreg("+", reference)
    vim.notify("Copied " .. reference)
end

-- Builds "path:first" or "path:first-last" and copies it.
local function copy_lines(first_line, last_line, full_path)
    local reference_path = current_file_path(full_path)
    if not reference_path then return end

    local reference = reference_path .. ":" .. first_line
    if last_line ~= first_line then reference = reference .. "-" .. last_line end
    copy_text(reference)
end

-- Normal mode: the cursor's line.
---@param options? { full_path?: boolean }
function M.copy_cursor(options)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    copy_lines(cursor_line, cursor_line, (options or {}).full_path)
end

-- Visual mode: the selected lines, in either direction. `v` is the other end of the
-- selection while still in visual mode; leave visual mode afterwards, as `y` does.
---@param options? { full_path?: boolean }
function M.copy_selection(options)
    local anchor_line = vim.fn.line("v")
    local cursor_line = vim.fn.line(".")
    copy_lines(math.min(anchor_line, cursor_line), math.max(anchor_line, cursor_line), (options or {}).full_path)
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end

-- The current file's path alone, without a line: for naming a whole file.
---@param options? { full_path?: boolean }
function M.copy_file(options)
    local reference_path = current_file_path((options or {}).full_path)
    if reference_path then copy_text(reference_path) end
end

-- The directory the current file is in: for naming a module or package rather than
-- one file. Relative to the reference root like the other copies, so a file at the
-- root itself gives ".".
---@param options? { full_path?: boolean }
function M.copy_directory(options)
    local reference_path = current_file_path((options or {}).full_path)
    if reference_path then copy_text(vim.fs.dirname(reference_path)) end
end

return M
