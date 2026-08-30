#!/bin/bash

# Set history size (number of lines kept in memory and in the file)
HISTSIZE=5000
HISTFILE=~/.bash_history
HISTFILESIZE=5000

# Avoid duplicate entries
# Ignore commands starting with space
export HISTCONTROL=ignoredups:erasedups:ignorespace

# Append to the history file, don't overwrite it
shopt -s histappend

# Share history between terminal sessions
# PROMPT_COMMAND+=('history -a')
# PROMPT_COMMAND+=('history -n')
