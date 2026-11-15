local augroup = vim.api.nvim_create_augroup
local group = augroup("user", {})

local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked symbols
autocmd({ "TextYankPost" }, {
    group = group,
    pattern = "*",
    callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 300 }) end,
})

-- Yank into primary clipboard
vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    pattern = "*",
    callback = function()
        if vim.v.event.operator == "y" then vim.fn.setreg("*", vim.v.event.regcontents, vim.v.event.regtype) end
    end,
})

-- Reload files changed outside nvim, e.g. by an agent in another pane.
-- `autoread` is on by default but only acts when nvim checks the files,
-- which it does on its own only around shell commands; `:checktime` makes it
-- check: on coming back to nvim (FocusGained, through tmux's focus-events),
-- on switching buffers, and after a moment idle, for changes that land while
-- I'm in nvim. Buffers with unsaved edits aren't reloaded; nvim asks instead.
autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    callback = function()
        -- `:checktime` isn't allowed in the command-line window (E11).
        if vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
    end,
})

-- Say which file was reloaded, as the reload itself is silent and may move
-- lines under the cursor.
autocmd("FileChangedShellPost", {
    group = group,
    callback = function(event) vim.notify("Reloaded " .. vim.fn.fnamemodify(event.file, ":~:."), vim.log.levels.INFO) end,
})

-- Keep cursor in the middle of the screen
autocmd({ "BufEnter", "WinEnter", "WinNew", "VimResized" }, {
    group = group,
    pattern = "*",
    command = "let &scrolloff=(winheight(win_getid())/2) + 1",
})
