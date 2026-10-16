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

# Lists the proposed files not taken yet: missing from the repository, or
# different from it. Shared by _claude_pick and claude-clean.
# Globals:
#   repository, proposals - read; set by _claude_directories in the caller
# Outputs:
#   Writes one path per line to stdout, relative to the repository root.
_claude_untaken() {
    local path
    find "${proposals}" -type f -printf '%P\n' | sort | while IFS= read -r path; do
        cmp --silent -- "${proposals}/${path}" "${repository}/${path}" || printf '%s\n' "${path}"
    done
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

    _claude_untaken | fzf --multi --preview "${preview}"
}

# Opens the proposed files in one nvim, with nvim's built-in difftool.
# Arguments:
#   $@ - optional; see _claude_pick
claude-diff() {
    local repository proposals
    _claude_directories || return

    local paths path
    mapfile -t paths < <(_claude_pick "$@")
    ((${#paths[@]} > 0)) || return 0

    # The difftool compares two directories, and would list every repository
    # file without a proposal, and every proposal not picked. So it gets two
    # directories with links to the picked files only. It resolves the links,
    # so its windows hold the real files, and saves go to the repository. A
    # new file has no link on the repository side and shows as added.
    local view
    view="$(mktemp --directory)" || return
    mkdir --parents -- "${view}/repository" "${view}/proposals"
    for path in "${paths[@]}"; do
        if [[ ! -f ${proposals}/${path} ]]; then
            printf 'No proposed file for %s in %s\n' "${path}" "${proposals}" >&2
            continue
        fi
        mkdir --parents -- "$(dirname -- "${view}/repository/${path}")" "$(dirname -- "${view}/proposals/${path}")"
        if [[ -e ${repository}/${path} ]]; then
            ln --symbolic -- "${repository}/${path}" "${view}/repository/${path}"
        fi
        ln --symbolic -- "${proposals}/${path}" "${view}/proposals/${path}"
    done

    # nvim -d with two directories hands them to the difftool.
    nvim -d "${view}/repository" "${view}/proposals"
    # Only the links go; rm doesn't follow them.
    rm --recursive --force -- "${view}"
}

# Copies proposed files into the repository, creating directories as needed,
# then deletes each one it copied, and directories that leaves empty: what
# stays in the proposals directory is what's still pending. A working copy such
# as TODO.md goes too; Claude starts the next one from the repository's file.
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
        cp --preserve=mode --verbose -- "${proposals}/${path}" "${repository}/${path}" || continue
        # Taken, so no longer a proposal. rmdir runs inside the proposals
        # directory with a relative path, so --parents stops below it.
        rm -- "${proposals}/${path}"
        if [[ ${path} == */* ]]; then
            (cd -- "${proposals}" && rmdir --parents --ignore-fail-on-non-empty -- "${path%/*}")
        fi
    done
    # After the last proposal, the directory itself goes too, so the next
    # claude-diff or claude-take says there's nothing, instead of an empty fzf.
    if [[ -d ${proposals} ]]; then
        rmdir --ignore-fail-on-non-empty -- "${proposals}"
    fi
}

# Deletes the directory of proposed files for the repository, so outdated
# proposals don't pile up across sessions. Without untaken files it deletes
# right away; otherwise it lists them and asks first, as they'd be lost. A
# working copy such as TODO.md counts as taken once it matches the repository,
# and Claude starts a new one from the repository next session.
# Outputs:
#   Writes the untaken files to stdout, and the question and result to stderr.
# Returns:
#   Non-zero outside a git repository, or when the deletion is declined.
claude-clean() {
    local repository proposals
    _claude_directories || return

    if [[ ! -d ${proposals} ]]; then
        printf 'No proposed files in %s\n' "${proposals}" >&2
        return
    fi
    # A guard for the rm below: a repository at / would leave the name empty,
    # and proposals would be /tmp/claude-<uid>/ itself, Claude Code's own
    # session files included.
    if [[ ${proposals} != /tmp/claude-+([0-9])/+([^/]) ]]; then
        printf 'Refusing to delete %s\n' "${proposals}" >&2
        return 1
    fi

    local untaken answer
    mapfile -t untaken < <(_claude_untaken)
    if ((${#untaken[@]} > 0)); then
        printf '%s\n' "${untaken[@]}"
        read -r -p "Delete ${proposals}, with the ${#untaken[@]} untaken files above? [y/N] " answer
        [[ ${answer} == [yY] ]] || return 1
    fi
    rm --recursive --force -- "${proposals}"
    printf 'Deleted %s\n' "${proposals}" >&2
}
