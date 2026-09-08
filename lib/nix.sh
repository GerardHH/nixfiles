#shellcheck shell=bash
#
# Shared helpers for interacting with Nix, should be sourced, never executed.

#shellcheck source=./log.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/log.sh"

# Flake reference, defaults to the release-26.05 branch of nix-community/home-manager
HM_REF="${HM_REF:-github:nix-community/home-manager/release-26.05}"

# Explains why Nix is unavailable, gives advice and terminates.
# Outputs:
#   Writes a diagnosis and suggested commands to stderr.
# Returns:
#   Does not return; exits 1.
diagnose_missing_nix() {
	printf '\033[1;31merror:\033[0m nix is not on PATH after setup.\n\n' >&2

	if [[ ! -d /nix ]]; then
		cat >&2 <<'EOF'
  /nix does not exist, so the installer never completed. Re-run this
  script and read its output, or install by hand to see the failure:

    curl --silent --show-error --fail --location \
      https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
EOF
	elif [[ ! -x /nix/var/nix/profiles/default/bin/nix ]]; then
		if [[ -e /nix/receipt.json ]]; then
			cat >&2 <<'EOF'
  /nix exists but holds no nix binary, and an install receipt is present.
  A previous install was almost certainly interrupted. Repair it:

    /nix/nix-installer repair

  Or start clean, then re-run this script:

    /nix/nix-installer uninstall
EOF
		else
			cat >&2 <<'EOF'
  /nix exists but holds no nix binary, and there is no install receipt at
  /nix/receipt.json. That means /nix came from something other than this
  installer — the nix-bin apt package, nix-portable, or a manual extraction.
  Remove that installation (or move /nix aside) before re-running.
EOF
		fi
	else
		cat >&2 <<'EOF'
  The binary exists at /nix/var/nix/profiles/default/bin/nix but the
  environment did not load. Check the daemon and the generated profile:

    systemctl status nix-daemon.service --no-pager
    ls -l /nix/var/nix/profiles/default/etc/profile.d/
EOF
	fi

	cat >&2 <<'EOF'

  Diagnostics for any of the above:

    /nix/nix-installer self-test
EOF
	exit 1
}

# Loads Nix into the current shell environment.
# Sources the first profile script found among the known locations: the
# multi-user (daemon) install and the single-user install used by the
# devcontainer Nix feature write differently named scripts in different
# places. Sourcing sets NIX_SSL_CERT_FILE, without which Nix cannot fetch
# over TLS, so the explicit PATH export is a fallback and not a substitute.
# Globals:
#   HOME - read
#   PATH - modified; Nix profile bin directories are prepended
#   NIX_SSL_CERT_FILE, NIX_PATH - set indirectly by the sourced script
# Outputs:
#   None on success; the sourced script may print on failure.
# Returns:
#   0 always, including when no profile script is found. Callers must
#   verify Nix is usable afterwards, e.g. with diagnose_missing_nix.
load_nix() {
	local candidate
	for candidate in \
		/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
		/nix/var/nix/profiles/default/etc/profile.d/nix.sh \
		"${HOME}/.nix-profile/etc/profile.d/nix.sh" \
		/etc/profile.d/nix.sh; do
		if [[ -e ${candidate} ]]; then
			set +o nounset
			#shellcheck source=/dev/null
			. "${candidate}"
			set -o nounset
			break
		fi
	done

	export PATH="/nix/var/nix/profiles/default/bin:${HOME}/.nix-profile/bin:${PATH}"
}

# Verifies a directory is a git work tree and reports untracked files.
# Flakes evaluate from the git index, so an unstaged new file does not
# exist as far as Nix is concerned. Modifications to tracked files are
# picked up normally, so only untracked paths are reported.
# Arguments:
#   $1 - path to the repository
# Outputs:
#   Writes a warning and the untracked paths to stderr when any exist.
# Returns:
#   0 if the path is a work tree; otherwise calls die and does not return.
require_git_tracked() {
	local repo="$1"
	git -C "${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
		die "${repo} is not a git repo; flakes need one."

	local untracked
	mapfile -t untracked < <(git -C "${repo}" ls-files --others --exclude-standard)
	if ((${#untracked[@]} > 0)); then
		warn "Untracked files are invisible to the flake:"
		printf '       %s\n' "${untracked[@]}"
	fi
}

# Activates a Home Manager profile.
# Uses the home-manager binary when it is on PATH, and otherwise bootstraps
# through `nix run`, which is the case on a first activation before
# programs.home-manager.enable has installed it.
#
# Always passes -b backup, in case of pre-existing files/folders.
# Globals:
#   HM_REF - Flake reference used for bootstrapping
# Arguments:
#   $1 - repository path containing flake.nix
#   $2 - profile name, matching an attribute of homeConfigurations
#   $@ - remaining arguments forwarded to home-manager switch
# Outputs:
#   Writes activation progress to stdout and stderr.
# Returns:
#   The exit status of home-manager switch.
hm_switch() {
	local repo="$1" profile="$2"
	shift 2
	log "Activating ${profile}"
	if command -v home-manager >/dev/null 2>&1; then
		home-manager switch -b backup --flake "${repo}#${profile}" "$@"
	else
		nix --extra-experimental-features "nix-command flakes" \
			run "${HM_REF}" -- \
			switch -b backup --flake "${repo}#${profile}" "$@"
	fi
}
