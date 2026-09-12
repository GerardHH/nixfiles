#!/usr/bin/env bash
#
# Installs Nix with flakes and activates a Home Manager profile on a fresh machine.
# Idempotent: skips the Nix install when /nix is already populated.
#
# Usage:
#   install.sh [profile]
#
# Arguments:
#   profile - profile to activate. If empty, defaults to "container" if in container.
#             Otherwise what was recorded in '~/.config/nixfiles/profile'.
#             If non apply, then "personal".
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#   Records the activated profile in '~/.config/nixfiles/profile'.
#
# Returns:
#   0 on success; non-zero from a failed precondition or from home-manager.

set -o errexit -o nounset -o pipefail

#shellcheck source=./lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

[[ "$(uname --kernel-name)" == "Linux" ]] || die "This script targets Linux."
[[ ${EUID} -ne 0 ]] || die "Run as your normal user; sudo is invoked where needed."
command -v curl >/dev/null || die "curl missing: sudo apt install --yes curl"
command -v git >/dev/null || die "git missing: sudo apt install --yes git"

PROFILE="$(resolve_profile "${1:-}")"
require_profile "${NIXFILES_REPO_DIR}" "${PROFILE}"
require_profile_prerequisites "${PROFILE}"

if [[ -e /nix/var/nix/profiles/default ]]; then
	log "Nix already present, skipping install"
else
	log "Installing Nix"
	curl --silent --show-error --fail --location \
		https://artifacts.nixos.org/nix-installer |
		sh -s -- install --enable-flakes --no-confirm
fi

load_nix
command -v nix >/dev/null || diagnose_missing_nix

require_git_tracked "${NIXFILES_REPO_DIR}"

hm_switch "${NIXFILES_REPO_DIR}" "${PROFILE}"

is_container || write_profile "${PROFILE}"

log "Done. Open a new shell, then rebuild with: 'nix-switch.sh'"
