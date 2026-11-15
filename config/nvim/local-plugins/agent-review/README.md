# agent-review

Review an agent's changes in nvim through git. The agent edits the working
tree; whatever isn't staged yet is what's left to review. Staging a hunk
accepts it, resetting it rejects it, with any git tool (gitsigns, lazygit,
`git add`). Built on git alone, so it works the same for any agent (Claude
Code, Copilot CLI, …) as long as it writes a notes file.

## What it shows

- **The list**: one entry per unstaged hunk and per untracked file, each with
  the agent's note for it. In trouble.nvim (`:Trouble agent_review`) grouped
  "This round" and "Earlier rounds", then per file, with the line range in front
  and the note after it. It refreshes on save, on focus, when gitsigns stages or
  resets a hunk, and when the agent rewrites the notes file at the end of its
  turn (`r` by hand), and follows the change under the cursor in the file. The
  notes file is watched only while the list is open; on a change, open buffers
  are reloaded too (`:checktime`). Without trouble, the same entries go to the
  quickfix list (`require("agent_review").to_quickfix()`).
- **The changes in the files**, while the trouble list is open, in one of two
  layouts:
  - *inline*: removed lines as virtual lines where they were (`DiffDelete`),
    added lines `DiffAdd`, lines that replace removed ones `DiffChange`.
  - *side by side*: the index version (the file before the agent's changes)
    in a window on the left, in nvim's diff mode against the file in view,
    trouble's preview included.

  `require("agent_review").toggle_review_layout()` switches, also during a
  review; `vim.g.agent_review_layout = "side_by_side"` makes a review start
  that way (default `"inline"`).
- **Previews** in trouble use the file's real buffer, so highlighting and
  gitsigns work there. Files only previewed are unloaded and unlisted again
  when the preview moves on or the list closes.

## The notes file

`.agent-notes.md` at the repository root, rewritten by the agent every turn
to describe what's still unstaged (not a history). Keep it out of git, e.g.
in the global ignore file.

```markdown
# nvim: Title of the change, as a commit subject

Free text: what the change as a whole does, and what this round changed.

## config/nvim/lua/plugins/trouble.lua

- `7-18` — why, in a sentence or two · new
- `92` — why
- `70`, `84` — one note for two changes
- `other/file.lua:12` — an item may name its own file anywhere
```

- A `## path` heading names a file, from the repository root; the items
  under it give lines in the working tree: one line or `first-last`, in
  backticks or not. Several locations, separated by commas, share one note.
- An item may wrap over several lines, as a Markdown formatter rewraps it:
  indented lines below an item continue it, up to the next item, heading,
  blank line or unindented line.
- The separator before the note may be an em or en dash, a hyphen or a
  colon.
- `· new` at the end marks a change from this round: it's listed under
  "This round", and the mark itself is left out of the text.
- A note becomes the text of each entry whose hunk it overlaps; an entry
  without one shows its first added line (or `removed: …`). Notes that
  match no unstaged change are counted in a warning.
- Write the notes last in the agent's turn, with the lines exactly as
  `git diff --unified=0` gives them: that's how stale notes are told apart
  (see below).

## Stale notes

The notes give lines as they were when the agent wrote them. Resetting or
editing a hunk afterwards moves the lines below it, so notes there point at the
wrong change until the agent's next turn rewrites them. Staging doesn't: it
changes the index, not the working tree.

A file's notes count as stale when the file was written after the notes file and
its hunks no longer pair up one to one with its note locations. Both checks are
needed: a save that changes nothing passes the second, and a staged hunk (its
note left without a hunk) never fails the first. Notes in a stale file are
marked `⚠` in the trouble list (`[stale?]` in quickfix), and a warning names the
files, once per set. They still land by line number: moving them onto their own
hunks again is in "Not yet".

## Setup

lazy.nvim, as a local plugin; trouble.nvim is optional:

```lua
{
    dir = vim.fn.stdpath("config") .. "/local-plugins/agent-review",
    name = "agent-review",
    keys = {
        { "<leader>ar", "<CMD>Trouble agent_review toggle<CR>", desc = "Agent review" },
        { "<leader>as", function() require("agent_review").toggle_review_layout() end },
    },
}
```

The keys load this plugin before trouble opens the mode: trouble looks for
sources (`lua/trouble/sources/agent_review.lua`) only in plugins already
loaded.

## Tip: reload files the agent changed

The agent writes the files on disk while they're open in nvim. nvim's `autoread`
is on by default, but only acts when nvim checks the files, which it does on its
own only around shell commands. So an open buffer keeps showing the old text
until `:e`. Make nvim check on coming back to it, on switching buffers and after
a moment idle:

```lua
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    callback = function()
        -- `:checktime` isn't allowed in the command-line window (E11).
        if vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
    end,
})

-- The reload is silent; say which file it was.
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    callback = function(event) vim.notify("Reloaded " .. vim.fn.fnamemodify(event.file, ":~:.")) end,
})
```

- Buffers with unsaved edits aren't reloaded: nvim asks which version to
  keep.
- Inside tmux, nvim only gets `FocusGained` with `set -g focus-events on`
  in `tmux.conf` (off by default). The trouble list refreshes on
  `FocusGained` too.
- `CursorHold` fires once per idle spell, so a change that lands while
  you're idle in nvim shows on your next key. While the trouble list is
  open, its notes watch reloads them at the end of the agent's turn anyway.

## Known issues

- **Preview overlaps after toggling to side by side.** With trouble's
  preview open, switching to side by side opens the index window by
  splitting the main window, but the preview float was sized to the main
  window before that, so it overlaps the index window. It's right again
  from the next preview on (an item in another file, or closing and
  reopening the list). A fix would close the preview before splitting so
  trouble reopens it at the new size; that needs a hook into trouble from
  `agent_review` itself.

## Not yet

- **Stale notes stay on the wrong change**, marked (see "Stale notes"),
  until the agent's next turn. Planned: while the notes are fresh, record
  each note's hunk content, and find the hunk by that content once they're
  stale.

## Tests

Specs in `tests/unit`, run by plenary.nvim's busted in headless nvim. They drive
`collect` on scratch git repositories made per test (`tests/helpers.lua`), with
file times set rather than waited for. See the `Makefile` for what runs where:

```sh
make test                                     # clones plenary.nvim first
make test DEPS=$HOME/.local/share/nvim/lazy   # or uses lazy.nvim's
```
