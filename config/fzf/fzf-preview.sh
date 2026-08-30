#!/bin/bash

__git_preview() {
	local target=$1

	if git show-ref --verify --quiet "refs/heads/$target"; then
		# It's a local branch
		git log -n 20 --oneline --graph --decorate "$target" --color=always

	elif git cat-file -e "$target" 2>/dev/null; then
		# Valid Git object
		type=$(git cat-file -t "$target")
		case "$type" in
		commit)
			git show --color=always --stat "$target"
			;;
		tree)
			git ls-tree "$target" | less -R
			;;
		blob)
			git show "$target" | bat --style=numbers --color=always --paging=never --language=auto 2>/dev/null || git show "$target" | head -n 40
			;;
		tag)
			git show "$target" --color=always
			;;
		*)
			echo "Unknown Git object type: $type"
			;;
		esac
	fi
}

__fzf_preview() {
	target=$1

	if [[ -d "$target" ]]; then
		eza --icons --color=always --all --tree --level=1 "$target"
	elif [[ -f "$target" ]]; then
		bat --style=numbers --color=always "$target" 2>/dev/null || head -n 40 "$target"
	elif git rev-parse --git-dir &>/dev/null; then
		__git_preview "$target"
	elif command -v "$target" &>/dev/null; then
		"$target" --help || man "$target"
	fi
}
