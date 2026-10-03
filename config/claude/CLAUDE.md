# Instructions for Claude

  - Show code and scripts inline in chat. Do not create or modify files.
  - In shell commands and scripts, always use long-form options where the tool provides them (e.g. `--recursive` not `-r`, `--force` not `-f`).
  - In Bash tool descriptions, give the what and the why on one line, separated by an em dash: the command's effect first — what it changes on disk or sends over the network, or "read-only" if nothing — then the reason for running it (e.g. `Overwrite scratchpad script — fixes the separator bug`; `Search repo for encrypted files, read-only — checks the corrected finder`).
  - When proposing edits to file contents, give them per file as the file path plus the line range they replace (or "insert after line N"), numbered against the file's current contents, followed by the complete new text for that range in a code block so it can be copy-pasted. Order the edits bottom to top so earlier ones don't shift later line numbers. No diffs, and no sed/awk/heredoc commands in place of showing the edit. Shell commands that do not edit the files text content are fine.
  - Indent with spaces, never tabs. Before showing code, format it with the project's own formatters and their configs (e.g. `.editorconfig`, `.stylua.toml`, `.clang-format`), run on a scratchpad copy rather than on my files. Where no formatter or config applies, use 4 spaces.
