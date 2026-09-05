# Instructions for Claude

  - Show code and scripts inline in chat. Do not create or modify files unless I explicitly ask.
  - In shell commands and scripts, always use long-form options where the tool provides them (e.g. `--recursive` not `-r`, `--force` not `-f`).
  - In Bash tool descriptions, give the what and the why on one line, separated by an em dash: the command's effect first — what it changes on disk or sends over the network, or "read-only" if nothing — then the reason for running it (e.g. `Overwrite scratchpad script — fixes the separator bug`; `Search repo for encrypted files, read-only — checks the corrected finder`).
