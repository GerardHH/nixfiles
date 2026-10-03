#!/usr/bin/env bash
#
# Build a dev-container if old or doesn't exist, found in '.devcontainer/devcontainer.json' and:
# 1. Mount /nix into the container.
# 2. Download nixfiles from GitHub and run 'install.sh'.
#
# Then start it and drop into it with a shell.
#
#
# Usage:
#   nix-devcontainer.sh [workspace-folder] [devcontainer-args...]
#
# Arguments:
#   workspace-folder  - directory holding .devcontainer/. Defaults to $PWD.
#   devcontainer-args - remaining arguments forwarded to 'devcontainer up'
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#
# Returns:
#   0 on success; 1 from any failed precondition.

set -o errexit -o nounset -o pipefail

#shellcheck source=./../lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if is_container; then
    die "This is a host tool; it drives the dev container through podman."
fi

command -v devcontainer >/dev/null || die "devcontainer is not on PATH; is pkgs.devcontainer in home.packages?"
command -v podman >/dev/null || die "podman missing: sudo apt install --yes podman"

WORKSPACE="$(realpath -- "${1:-${PWD}}")"

default_options=(
    --docker-path podman
    --workspace-folder "${WORKSPACE}"
)

devcontainer up \
    "${default_options[@]}" \
    --mount "type=bind,source=/etc/nix,target=/etc/nix" \
    --mount "type=bind,source=/nix,target=/nix" \
    --mount "type=bind,source=${NIXFILES_REPO_DIR},target=/home/ubuntu/nixfiles" \
    --remove-existing-container

#shellcheck disable=SC2088
devcontainer exec \
    "${default_options[@]}" \
    bash -lc '~/nixfiles/install.sh'

devcontainer exec \
    "${default_options[@]}" \
    bash
