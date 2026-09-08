#!/usr/bin/env bash
#
# Updates the flake lock and re-activates the profile with the new packages.
# Does not upgrade Nix itself; see the TODO below.
#
# Usage:
#   nix-update.sh [profile] [@]
#
# Arguments:
#   profile - profile to activate. If empty, defaults to "container" if in container.
#             Otherwise what was recorded in '~/.config/nixfiles/profile'.
#             If non apply, then "personal".
#   @       - remaining arguments forwarded to home-manager switch
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#
# Returns:
#   0 on success; non-zero from a failed precondition or from home-manager.

set -o errexit -o nounset -o pipefail

#shellcheck source=./../lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

REQUESTED_PROFILE=""
if [[ -n ${1:-} && ${1} != -* ]]; then
	REQUESTED_PROFILE="${1}"
	shift
fi

PROFILE="$(resolve_profile "${REQUESTED_PROFILE}")"
require_profile "${NIXFILES_REPO_DIR}" "${PROFILE}"

require_git_tracked

load_nix
command -v nix >/dev/null || diagnose_missing_nix

log "Updating nix"
# TODO Skipped because of "not trusted user", sudo doesn't work
# sudo nix upgrade-nix

pushd "${NIXFILES_REPO_DIR}" >/dev/null
log "Updating flake"
nix flake update --flake .
hm_switch "${NIXFILES_REPO_DIR}" "${PROFILE}" "$@"
popd >/dev/null
