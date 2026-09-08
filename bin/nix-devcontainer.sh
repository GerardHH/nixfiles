#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname -- "$(dirname -- "${SCRIPT_PATH}")")"
# shellcheck source=../lib/common.sh
. "${REPO_DIR}/lib/common.sh"

[[ "$(detect_profile)" != "container" ]] ||
	die "This is a host tool; it drives the dev container through podman."

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
	--workspace-folder \
	"${WORKSPACE}" \
	--docker-path podman \
	bash
