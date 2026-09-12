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

# Explains how to restore a missing secrets checkout and terminates.
# Arguments:
#   $1 - checkout path
#   $@ - files that were expected inside it and are not there
# Returns:
#   Does not return; exits 1.
die_missing_secrets_checkout() {
	local checkout="${1}"
	shift
	printf '\033[1;31merror:\033[0m secrets checkout at %s is missing %d file(s)\n\n' "${checkout}" "$#" >&2
	printf '    %s\n' "$@" >&2
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

  Already cloned? Then it is out of date, or on the wrong branch.
EOF
	exit 1
}

# Explains how to restore a missing SSH key and terminates.
# Arguments:
#   $1 - path the key was expected at
#   $2 - one line on where to get it
# Returns:
#   Does not return; exits 1.
die_missing_ssh_key() {
	printf '\033[1;31merror:\033[0m no SSH key at %s\n\n' "${1}" >&2
	cat >&2 <<EOF
  This key is deliberately not managed by Nix: it is what fetches the
  secrets, so nothing declarative can bootstrap it. Place it by hand,
  once per machine:

    install --mode=600 /path/to/key "${1}"

  ${2}
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

# Verifies a secrets checkout is present and holds everything the profile
# reads from it.
# Deliberately does not clone: the remote is company infrastructure and is
# not recorded in this public repo, so the checkout is made by hand.
# Deliberately does not pull either, since a silent update would change what
# the next activation installs.
# Arguments:
#   $1 - checkout path
#   $@ - one or more files that must exist inside it, relative to the checkout
# Returns:
#   0 when every file is present; otherwise calls die and does not return.
require_secrets_checkout() {
	local checkout
	checkout="${1:-}"
	[[ -n "${checkout}" ]] || die "require_secrets_checkout: 'checkout path' may not be empty"
	shift

	(($# > 0)) || die "require_secrets_checkout: needs at least one expected file"

	local missing=() expected
	for expected in "$@"; do
		[[ -r "${checkout}/${expected}" ]] || missing+=("${expected}")
	done

	((${#missing[@]} == 0)) || die_missing_secrets_checkout "${checkout}" "${missing[@]}"
}

# Verifies an SSH private key is present, private enough for ssh to accept,
# and actually parses as a private key.
# The mode test masks the group and other bits rather than whitelisting 600
# and 400, because that is the test ssh itself applies.
# Arguments:
#   $1 - path to the private key
#   $2 - one line on where to get it, shown when it is missing
# Returns:
#   0 when the key is usable; otherwise calls die and does not return.
require_ssh_key() {
	local key_path hint
	key_path="${1:-}"
	hint="${2:-}"
	[[ -n "${key_path}" ]] || die "require_ssh_key: 'key path' may not be empty"

	[[ -r ${key_path} ]] || die_missing_ssh_key "${key_path}" "${hint}"

	local mode
	mode="$(stat --format='%a' -- "${key_path}")"
	(((8#${mode} & 8#77) == 0)) ||
		die "${key_path} is mode ${mode}; ssh refuses a key others can read. Fix with: chmod 600 ${key_path}"

	if command -v ssh-keygen >/dev/null 2>&1; then
		# </dev/null so an encrypted key fails instead of prompting.
		ssh-keygen -y -f "${key_path}" >/dev/null 2>&1 </dev/null ||
			die "${key_path} does not parse as a private key: truncated, wrong format, or passphrase-protected. This setup uses passphrase-less keys."
	else
		warn "ssh-keygen not on PATH; skipped validating ${key_path}."
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
