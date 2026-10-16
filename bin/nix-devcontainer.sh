#!/usr/bin/env bash
#
# Build a dev-container if old or doesn't exist, found in '.devcontainer/devcontainer.json' and:
# 1. Mount /nix into the container.
# 2. Download nixfiles from GitHub and run 'install.sh'.
#
# Then start it and drop into it with a shell, or run a command in it.
#
#
# Usage:
#   nix-devcontainer.sh [workspace-folder] [devcontainer-args...] [-- command...]
#
# Arguments:
#   workspace-folder  - directory holding .devcontainer/. Defaults to $PWD.
#   devcontainer-args - arguments up to '--', forwarded to 'devcontainer up'
#   command           - after '--': run this in the workspace folder, in a
#                       login shell for the nixfiles environment, instead of
#                       dropping into a shell. For scripted runs, such as
#                       a project's tests.
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#
# Returns:
#   0 on success; 1 from any failed precondition; with a command, its status.

set -o errexit -o nounset -o pipefail

#shellcheck source=./../lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if is_container; then
    die "This is a host tool; it drives the dev container through podman."
fi

command -v devcontainer >/dev/null || die "devcontainer is not on PATH; is pkgs.devcontainer in home.packages?"
command -v podman >/dev/null || die "podman missing: sudo apt install --yes podman"

WORKSPACE="${PWD}"
# A leading '--' means no workspace folder, only a command.
if (($# > 0)) && [[ $1 != -- ]]; then
    WORKSPACE="$1"
    shift
fi
WORKSPACE="$(realpath -- "${WORKSPACE}")"

# Arguments for 'devcontainer up' run up to '--'; the command follows it.
up_arguments=()
while (($# > 0)) && [[ $1 != -- ]]; do
    up_arguments+=("$1")
    shift
done
command_arguments=()
if (($# > 0)); then
    shift
    command_arguments=("$@")
fi

# Bash history per workspace, in a named podman volume rather than a host
# directory: it outlives a rebuilt container, and goes with podman's own
# cleanup (podman volume rm, or podman system prune --volumes). Volume names
# allow only [a-zA-Z0-9_.-], so other characters of the path become '-'.
HISTORY_VOLUME="nix-devcontainer-bash${WORKSPACE//[^a-zA-Z0-9_.-]/-}"

default_options=(
    --docker-path podman
    --workspace-folder "${WORKSPACE}"
)

devcontainer up \
    "${default_options[@]}" \
    --mount "type=bind,source=/etc/nix,target=/etc/nix" \
    --mount "type=bind,source=/nix,target=/nix" \
    --mount "type=bind,source=${NIXFILES_REPO_DIR},target=/home/ubuntu/nixfiles" \
    --mount "type=volume,source=${HISTORY_VOLUME},target=/home/ubuntu/.local/state/bash" \
    "${up_arguments[@]}"

# Podman creates missing parents of a mount target as root, and a new volume
# belongs to root too; hand them back.
podman exec \
    --user root \
    "$(podman ps --quiet --filter "label=devcontainer.local_folder=${WORKSPACE}")" \
    chown ubuntu:ubuntu /home/ubuntu/.local /home/ubuntu/.local/state /home/ubuntu/.local/state/bash

# Bootstrap nixfiles environment before dropping in.
#shellcheck disable=SC2088
devcontainer exec \
    "${default_options[@]}" \
    bash -lc '~/nixfiles/install.sh'

if ((${#command_arguments[@]} > 0)); then
    # A login shell, as for install.sh: it puts the nix profile, nvim among
    # it, on PATH. The command's words are bash's own arguments ("bash" fills
    # $0), so "$@" passes each on as given, without a second round of
    # quoting. errexit makes the script exit with the command's status.
    devcontainer exec \
        "${default_options[@]}" \
        bash -lc '"$@"' bash "${command_arguments[@]}"
else
    devcontainer exec \
        "${default_options[@]}" \
        bash
fi
