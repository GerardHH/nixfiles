#!/bin/bash

export FZF_DEFAULT_OPTS=" \
--height=60% \
--border \
--layout=reverse \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
# See https://github.com/lincheney/fzf-tab-completion/issues/85 on why {1} is needed.
export FZF_COMPLETION_OPTS='--preview "source ${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf-preview.sh; echo {1}; __fzf_preview {1}" --preview-window=right:60%:wrap'

FZF_TAB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fzf-tab-completion"
if [ -f "$FZF_TAB_DIR/bash/fzf-bash-completion.sh" ]; then
	source "$FZF_TAB_DIR/bash/fzf-bash-completion.sh"
	bind -x '"\t": fzf_bash_completion'
fi

__fzf_history_search() {
	BUFFER=$(history | cut --characters 8- | fzf --tac +s --no-sort --reverse --query "$READLINE_LINE")
	if [[ -n "$BUFFER" ]]; then
		READLINE_LINE="$BUFFER"
		READLINE_POINT=${#READLINE_LINE}
	fi
}
bind -x '"\C-r": __fzf_history_search'
