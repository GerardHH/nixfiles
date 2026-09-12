#!/usr/bin/env bash
#
# Activates a Home Manager profile to apply changes made in nixfiles repo.
#
# Usage:
#   nix-switch.sh [profile] [@]
#
# Arguments:
#   profile - profile to activate. If empty, defaults to "container" if in container.
#             Otherwise what was recorded in '~/.config/nixfiles/profile'.
#             If non apply, then "personal".
#   @       - remaining arguments forwarded to home-manager switch
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#   Records the activated profile in '~/.config/nixfiles/profile'.
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
require_profile_prerequisites "${PROFILE}"

load_nix
command -v nix >/dev/null || diagnose_missing_nix

require_git_tracked "${NIXFILES_REPO_DIR}"
hm_switch "${NIXFILES_REPO_DIR}" "${PROFILE}" "$@"

is_container || write_profile "${PROFILE}"
