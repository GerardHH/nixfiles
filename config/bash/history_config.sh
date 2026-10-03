#!/bin/bash

# Set history size (number of lines kept in memory and in the file)
HISTSIZE=5000
HISTFILESIZE=5000

# In a dev container, ~/.local/state/bash links to a per-workspace host directory
# (see bin/nix-devcontainer.sh). Bash doesn't create the directory itself.
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/bash/history"
[[ -d "${HISTFILE%/*}" ]] || mkdir --parents "${HISTFILE%/*}"

# Avoid duplicate entries
# Ignore commands starting with space
export HISTCONTROL=ignoredups:erasedups:ignorespace

# Append to the history file, don't overwrite it
shopt -s histappend

# Save each command right away
PROMPT_COMMAND+=('history -a')
# Share history between terminal sessions
# PROMPT_COMMAND+=('history -n')
