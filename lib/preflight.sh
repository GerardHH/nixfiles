#shellcheck shell=bash
#
# Preflight checks for the credentials a profile needs but cannot provide for
# itself. Source, never execute.
#
# Nothing here knows any profile by name. Each profile declares its own
# prerequisites in home/profiles/<name>/preflight.sh, using the reusable
# checks below; this file only supplies the vocabulary and runs the hook.

#shellcheck source=./log.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/log.sh"
#shellcheck source=./paths.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

# Explains how to restore a missing age identity and terminates.
# Arguments:
#   $1 - identity name
#   $2 - path the identity was expected at
# Returns:
#   Does not return; exits 1.
die_missing_age_identity() {
	printf '\033[1;31merror:\033[0m missing age identity '\''%s'\'' at %s\n\n' "${1}" "${2}" >&2
	cat >&2 <<EOF
  This profile deploys secrets encrypted to the '${1}' recipient, and this
  file holds the private half. It is never in the repo, so restore it from
  your password manager as one whole file, comments included:

    mkdir --parents "${NIXFILES_AGE_DIR}"
    install --mode=600 /dev/null "${2}"
    \${EDITOR} "${2}"

  Without it, activation fails when sops-nix tries to decrypt.
EOF
	exit 1
}

# Verifies every named age identity is present, then assembles them into the
# one file sops reads.
# sops.age.keyFile is a single path, so every identity a profile needs has to
# end up in one file. Keeping the parts separate on disk is what makes them
# separately restorable, and separately nameable when one is missing. The
# assembled file is derived: edit the parts, never keys.txt.
# Arguments:
#   $@ - identity names, each matching <name>.txt in NIXFILES_AGE_DIR
# Globals:
#   NIXFILES_AGE_DIR, NIXFILES_AGE_KEY_FILE - read
# Outputs:
#   Writes a progress message to stdout when the assembled file changes.
# Returns:
#   0 when every identity is present; otherwise calls die and does not return.
require_age_keys() {
	(($# > 0)) || die "require_age_keys: needs at least one identity name"

	local parts=() name part
	for name in "$@"; do
		part="${NIXFILES_AGE_DIR}/${name}.txt"
		[[ -r ${part} ]] || die_missing_age_identity "${name}" "${part}"
		grep --quiet -- "AGE-SECRET-KEY-" "${part}" ||
			die "${part} holds no AGE-SECRET-KEY- line, so it is not an age identity file."
		parts+=("${part}")
	done

	local assembled
	assembled="$(cat -- "${parts[@]}")"
	if [[ -r ${NIXFILES_AGE_KEY_FILE} ]] &&
		[[ "$(cat -- "${NIXFILES_AGE_KEY_FILE}")" == "${assembled}" ]]; then
		return 0
	fi

	install --mode=600 /dev/null "${NIXFILES_AGE_KEY_FILE}"
	printf '%s\n' "${assembled}" >"${NIXFILES_AGE_KEY_FILE}"
	log "Assembled age identities into ${NIXFILES_AGE_KEY_FILE}"
}

# Verifies a secrets checkout is present and holds what the profile reads.
# Deliberately does not clone: the remote is company infrastructure and is
# not recorded in this public repo, so the checkout is made by hand.
# Deliberately does not pull either, since a silent
# update would change what the next activation installs.
# Arguments:
#   $1 - checkout path
#   $2 - file that must exist inside it, relative to the checkout
# Returns:
#   0 when the checkout is usable; otherwise calls die and does not return.
require_secrets_checkout() {
	local checkout expected
	checkout="${1:-}"
	expected="${2:-}"
	[[ -n "${checkout}" ]] || die "require_secrets_checkout: 'checkout path' may not be empty"
	[[ -n "${expected}" ]] || die "require_secrets_checkout: 'expected file' may not be empty"

	if [[ ! -r "${checkout}/${expected}" ]]; then
		printf '\033[1;31merror:\033[0m no secrets checkout at %s\n\n' "${checkout}" >&2
		cat >&2 <<EOF
  This profile reads its secrets from a checkout, so the material never
  lands in this public flake. Nothing here can fetch it for you: the
  remote is not recorded in a public repo, and reaching it needs a work
  SSH key that no declarative config can bootstrap.

  On a fresh machine, in order:

    1. Put the work SSH key in place, mode 600.
    2. Clone the secrets repo to ${checkout}, naming the key
       explicitly so it works before any deployed ssh config exists:

         GIT_SSH_COMMAND='ssh -i ~/.ssh/<key> -o IdentitiesOnly=yes' \\
           git clone <remote> "${checkout}"

  Already cloned? Then ${expected} is missing from it: wrong remote, or
  it needs a pull.
EOF
		exit 1
	fi
}

# Runs a profile's own prerequisite checks, when it has any.
# Arguments:
#   $1 - profile name
# Globals:
#   NIXFILES_PROFILES_DIR - read
# Returns:
#   0 when the profile can be activated; otherwise calls die and does not return.
require_profile_prerequisites() {
	local profile
	profile="${1:-}"
	[[ -n "${profile}" ]] || die "require_profile_prerequisites: 'profile name' may not be empty"

	local hook="${NIXFILES_PROFILES_DIR}/${profile}/preflight.sh"
	[[ -r ${hook} ]] || return 0

	#shellcheck source=/dev/null
	source "${hook}"
}
