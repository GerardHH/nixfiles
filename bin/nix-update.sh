#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname "$(dirname -- "${SCRIPT_PATH}")")"
# shellcheck source=lib/common.sh
source "${REPO_DIR}/lib/common.sh"

PROFILE="${1:-$(detect_profile)}"

log "Updating nix"
# TODO Skipped because of "not trusted user", sudo doesn't work
# sudo nix upgrade-nix

pushd "${REPO_DIR}"
log "Updating flake"
nix flake update --flake .
hm_switch "${REPO_DIR}" "${PROFILE}" "$@"
