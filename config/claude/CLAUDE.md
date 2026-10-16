# Instructions for Claude

- Show code and scripts inline in chat. Do not create or modify files, except
  in my temp directory `/tmp/claude-1000` (see below).
- In shell commands and scripts, always use long-form options where the tool
  provides them (e.g. `--recursive` not `-r`, `--force` not `-f`).
- In Bash tool descriptions, give the what and the why on one line, separated
  by an em dash: the command's effect first — what it changes on disk or sends
  over the network, or "read-only" if nothing — then the reason for running it
  (e.g. `Overwrite scratchpad script — fixes the separator bug`;
  `Search repo for encrypted files, read-only — checks the corrected finder`).
- When proposing edits to file contents, give them per file: the file path,
  the line range being replaced (or "insert after line N"), numbered against
  the file's current contents, and the complete new text for that range in a
  code block, ready to copy-paste. With each range, also say where it sits in
  the file's structure, outermost first, like an editor's breadcrumbs (e.g.
  `lsp.lua` lines 91–94: `neovim/nvim-lspconfig` spec › `init` function ›
  `LspAttach` autocmd callback). Let the range start and end with one or two
  unchanged lines of context, as git diffs do, so the spot is easy to
  recognize. List a file's edits top to bottom, all numbered against the
  unedited file. No diffs, and no sed/awk/heredoc commands in place of showing
  the edit. Shell commands that do not edit the files text content are fine.
- Also write every file you propose, short change or long, as the complete
  file to `/tmp/claude-1000/<project>/<path in project>` (e.g.
  `/tmp/claude-1000/nixfiles/config/nvim/lua/plugins/new-plugin.lua`). Start
  from the project's current file; one already there that differs from it is
  a proposal I haven't taken yet, so build on it or ask. Then give the
  commands from `config/bash/claude.sh` in nixfiles, with paths relative to
  where I run them: `claude-diff <paths>` to review, `claude-take <paths>` to
  copy them in (it deletes what it took). Not `cp` or `nvim -d`. In chat, show
  changes up to about 50 lines per file as above; longer ones only by path.
- That directory holds only proposed files, at their path in the project.
  Scratch builds, copies for running tests, and logs go in the session
  scratchpad.
- Indent with spaces, never tabs. Before showing code, format it with the
  project's own formatters and their configs (e.g. `.editorconfig`,
  `.stylua.toml`, `.clang-format`), run on a scratchpad copy rather than on my
  files. Where no formatter or config applies, use 4 spaces.
- In code and config you suggest, comment each change with what it does and why
  you're suggesting it (the problem it solves, the choice behind it), even
  where the surrounding file has fewer comments. I'll trim what I don't need.
