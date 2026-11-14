# Instructions for Claude

- Make changes right in the project's working tree. I review them through
  git: what I stage is accepted, what I reset is rejected. So don't stage,
  commit, stash, reset or otherwise change the index or history unless I
  ask, and leave my own unstaged changes alone. Read-only git (`status`,
  `diff`, `log`, `show`) is fine.
- After a turn that changed files in a git repository, rewrite
  `.agent-notes.md` at its root so it describes what's still unstaged, not
  a history. `<leader>qg` in nvim lists the changes with these notes in
  trouble.nvim. The shape:

  ```markdown
  # nvim: Review agent changes in trouble.nvim

  What the change as a whole does, a few lines, kept current.

  This round: what this turn did, in reply to my last message.

  ## config/nvim/local-plugins/agent-review/lua/agent_review/init.lua

  - `7-18` — what changed and why, a sentence or two · new
  - `92` — what changed and why
  - `120`, `134-140` — one note for changes that belong together
  ```

  - Title: the change as a commit subject, in the repository's commit style
    (here `feat: nvim: …` without the type).
  - One `## path` heading per file, path from the repository root; under
    it one item per change on one line, its lines in the working tree as
    `git diff --unified=0` gives them (`1` for a new or deleted file).
    Changes that share a note go in one item, their lines separated by
    commas.
  - Notes as full as the chat summary's lines: what changed and why, not
    just a label; the list wraps them.
  - `· new` at the end of items added or changed this turn.
  - Cover every unstaged hunk and untracked file you made, this turn's and
    earlier ones I haven't staged or reset yet; drop the items for the rest.
    A new change, with a different title, starts the file afresh.
- Experiments, scratch builds, copies for running tests, and logs go in the
  session scratchpad, not in the project.
- End a turn that changed files with the same summary in chat: the notes
  file's text, with `path:line` or `path:first-last` instead of the file
  headings where that reads better. No code snippets for changes in the
  project; I read those in the files. Show code and scripts inline when
  they're the answer itself rather than a change to a file.
- When I bring a new task or question, first check whether the thinking
  effort fits it: higher for design choices, security boundaries (sandbox,
  permissions, credentials) and debugging; lower for mechanical edits and
  `TODO.md` upkeep. If it clearly doesn't fit, stop before starting: suggest
  the level in one line, say why, and wait. Not for small follow-ups or in
  the middle of a task.
- For files you aren't allowed to write (Claude Code's own settings, such as
  `config/claude/settings.json` and this file in nixfiles), write the
  complete file to `/tmp/claude-1000/<project>/<path in project>` instead.
  Start from the project's current file; one already there that differs
  from it is a proposal I haven't taken yet, so build on it or ask. Show
  the edits in chat per file: the line range being replaced (or "insert
  after line N"), numbered against the file's current contents, with the
  complete new text in a code block, and where it sits in the file's
  structure, outermost first, like an editor's breadcrumbs (e.g. `lsp.lua`
  lines 91–94: `neovim/nvim-lspconfig` spec › `init` function ›
  `LspAttach` autocmd callback). Start and end each range with one or two
  unchanged lines of context, list them top to bottom, and show up to about
  50 changed lines per file, longer ones by path only. No diffs. Then give
  the commands from `config/bash/claude.sh` in nixfiles, with paths
  relative to where I run them: `claude-diff <paths>` to review,
  `claude-take <paths>` to copy them in (it deletes what it took).
- In shell commands and scripts, always use long-form options where the tool
  provides them (e.g. `--recursive` not `-r`, `--force` not `-f`).
- In Bash tool descriptions, give the what and the why on one line, separated
  by an em dash: the command's effect first — what it changes on disk or sends
  over the network, or "read-only" if nothing — then the reason for running it
  (e.g. `Overwrite scratchpad script — fixes the separator bug`;
  `Search repo for encrypted files, read-only — checks the corrected finder`).
- Write commands I approve so I can review them at a glance: one step per
  line, with a comment above each step that isn't obvious, instead of long
  `&&` chains. Give variables descriptive names (`test_repository`, not `r`)
  and set them close to where they're used. Every `rm` names its target in
  full, or through a variable set a few lines above it, so I can see what
  gets deleted without hunting.
- Indent with spaces, never tabs. Format what you change with the project's
  own formatters and their configs (e.g. `.editorconfig`, `.stylua.toml`,
  `.clang-format`). Where no formatter or config applies, use 4 spaces.
- In code and config you write, comment each change with what it does and
  why (the problem it solves, the choice behind it), even where the
  surrounding file has fewer comments. I'll trim what I don't need.
- In code you write, name parameters and variables after what they hold
  (`repository_root`, not `root`; `diff_line`, not `line`; `left_entry`
  and `right_entry` in a sort, not `a` and `b`), in short functions and
  loops too. Names an API fixes (e.g. quickfix's `lnum`) stay as they are.
