#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname -- "${SCRIPT_PATH}")"
# shellcheck source=lib/common.sh
source "${REPO_DIR}/lib/common.sh"

[[ "$(uname --kernel-name)" == "Linux" ]] || die "This script targets Linux."
[[ ${EUID} -ne 0 ]] || die "Run as your normal user; sudo is invoked where needed."
command -v curl >/dev/null || die "curl missing: sudo apt install --yes curl"
command -v git >/dev/null || die "git missing: sudo apt install --yes git"
# [[ -d /run/systemd/system ]] ||
# 	warn "No systemd detected. Multi-user Nix needs it; on WSL enable systemd first."

PROFILE="${1:-$(detect_profile)}"

# 1. Nix, with flakes + nix-command enabled in /etc/nix/nix.conf
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

# 2. Flakes evaluate from the git index, so untracked files are invisible
require_git_tracked "${REPO_DIR}"

# 3. First run bootstraps via `nix run`; after that
#    programs.home-manager.enable puts the binary in your profile.
log "Activating ${PROFILE}"
hm_switch "${REPO_DIR}" "${PROFILE}"

log "Done. Open a new shell, then rebuild with:"
printf '    home-manager switch --flake %s#%s\n' "${REPO_DIR}" "${PROFILE}"
