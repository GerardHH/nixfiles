#!/usr/bin/env bash
# Claude Code status line: the vim mode in every mode, NORMAL included.
mode=$(jq --raw-output '.vim.mode // empty')
[[ -n "$mode" ]] && printf -- '-- %s --\n' "$mode"
exit 0
