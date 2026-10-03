#shellcheck shell=bash
#
# Reviews and applies the files Claude Code proposes. Claude writes each one to
# /tmp/claude-<uid>/<repository name>/<path in the repository>, so the path
# under that directory mirrors the file it replaces. Sourced by bashrc for
# interactive shells, never executed.

# Finds the repository and the directory holding Claude's proposed files for it.
# Sets the variables in the caller's scope: bash looks a variable up through the
# chain of calling functions, so the assignments land in the caller's locals.
# Globals:
#   repository - set; root of the git repository around the working directory
#   proposals - set; the directory mirroring it with Claude's proposed files
# Returns:
#   0 inside a git repository, git's non-zero status otherwise.
_claude_directories() {
    repository="$(git rev-parse --show-toplevel)" || return
    proposals="/tmp/claude-$(id --user)/${repository##*/}"
}

# Lists the proposed files to act on.
# Arguments:
#   $@ - optional; paths of files in the repository, relative to the working
#        directory. Without them, fzf offers the proposed files that differ
#        from the repository.
# Outputs:
#   Writes one path per line to stdout, relative to the repository root.
# Returns:
#   Non-zero outside a git repository, without a directory of proposed files,
#   or when fzf is cancelled.
_claude_pick() {
    local repository proposals
    _claude_directories || return

    if (($# > 0)); then
        realpath --canonicalize-missing --relative-to="${repository}" -- "$@"
        return
    fi

    if [[ ! -d ${proposals} ]]; then
        printf 'No proposed files in %s\n' "${proposals}" >&2
        return 1
    fi

    # fzf replaces {} with the highlighted line, quoted; %q quotes the
    # directories for the shell that runs the preview.
    local preview
    preview="diff --unified --new-file --color=always --"
    preview+=" $(printf '%q' "${repository}")/{} $(printf '%q' "${proposals}")/{}"

    local path
    find "${proposals}" -type f -printf '%P\n' | sort | while IFS= read -r path; do
        cmp --silent -- "${proposals}/${path}" "${repository}/${path}" || printf '%s\n' "${path}"
    done | fzf --multi --preview "${preview}"
}

# Opens each proposed file next to the file it replaces in nvim's diff mode.
# Arguments:
#   $@ - optional; see _claude_pick
claude-diff() {
    local repository proposals
    _claude_directories || return

    local paths path
    mapfile -t paths < <(_claude_pick "$@")

    for path in "${paths[@]}"; do
        nvim -d -- "${repository}/${path}" "${proposals}/${path}"
    done
}

# Copies proposed files into the repository, creating directories as needed.
# The proposed files stay, so a working copy such as TODO.md lasts across
# sessions; once copied, a file no longer shows up in the fzf list.
# Arguments:
#   $@ - optional; see _claude_pick
# Outputs:
#   Writes each copy to stdout, and each path without a proposed file to stderr.
claude-take() {
    local repository proposals
    _claude_directories || return

    local paths path
    mapfile -t paths < <(_claude_pick "$@")

    for path in "${paths[@]}"; do
        if [[ ! -f ${proposals}/${path} ]]; then
            printf 'No proposed file for %s in %s\n' "${path}" "${proposals}" >&2
            continue
        fi
        mkdir --parents -- "$(dirname -- "${repository}/${path}")"
        cp --preserve=mode --verbose -- "${proposals}/${path}" "${repository}/${path}"
    done
}
