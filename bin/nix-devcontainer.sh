#!/usr/bin/env bash
#
# Build a dev-container if old or doesn't exist, found in '.devcontainer/devcontainer.json' and:
# 1. Add the Nix feature.
# 2. Download nixfiles from GitHub and run 'install.sh'.
#
# Then start it and drop into it with a shell.
#
#
# Usage:
#   nix-devcontainer.sh [workspace-folder]
#
# Arguments:
#   workspace-folder - directory holding .devcontainer/. Defaults to $PWD.
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

WORKSPACE="$(realpath -- "${1:-${PWD}}")"

NIX_FEATURE='{
  "ghcr.io/devcontainers/features/nix:1": {
    "multiUser": false,
    "extraNixConfig": "experimental-features = nix-command flakes,sandbox = false,build-dir = /nix/var/tmp"
  }
}'

#shellcheck disable=SC2088
devcontainer up \
	--workspace-folder "${WORKSPACE}" \
	--docker-path podman \
	--dotfiles-repository https://github.com/GerardHH/nixfiles \
	--dotfiles-target-path '~/nixfiles' \
	--additional-features "${NIX_FEATURE}"

devcontainer exec \
	--workspace-folder "${WORKSPACE}" \
	--docker-path podman \
	bash
