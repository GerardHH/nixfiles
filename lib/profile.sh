#shellcheck shell=bash
#
# Shared helpers for interacting with supported profiles, should be sourced, never executed.

#shellcheck source=./log.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/log.sh"
#shellcheck source=./paths.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

# Plain text file containing which profile is active on this machine
NIXFILES_PROFILE_MARKER="${NIXFILES_CONFIG_DIR}/profile"

# Reports whether this machine is a container.
# Detection relies on markers written by the container runtime: Podman
# creates /run/.containerenv, Docker creates /.dockerenv, and the dev
# container tooling sets REMOTE_CONTAINERS.
# Globals:
#   REMOTE_CONTAINERS - read; set by the devcontainer CLI and VS Code
# Returns:
#   0 when running inside a container, 1 otherwise.
is_container() {
	[[ -f /run/.containerenv || -f /.dockerenv || -n ${REMOTE_CONTAINERS:-} ]]
}

# Extra options a profile needs on the nix command line, beyond the defaults.
# Read from an optional file in the profile directory, the same way
# require_profile_prerequisites picks up preflight.sh: a profile needing
# nothing extra simply has no file.
# Lines starting with a long form option are picked up, including everything
# that follows (such as arguments). All other lines are ignored.
# Arguments:
#   $1 - profile name
# Globals:
#   NIXFILES_PROFILES_DIR - read
# Outputs:
#   Writes one argument per line to stdout. Nothing when the profile has no file.
profile_nix_args() {
	local profile
	profile="${1:-}"
	[[ -n "${profile}" ]] || die "profile_nix_args: 'profile name' may not be empty"

	local args_file="${NIXFILES_PROFILES_DIR}/${profile}/nix-args"
	[[ -r ${args_file} ]] || return 0

	# local - restores on return whatever this function changes.
	local -
	set -o noglob

	local line
	while read -r line || [[ -n ${line} ]]; do
		if [[ ${line} == --* ]]; then
			# shellcheck disable=SC2086
			printf '%s\n' ${line}
		fi
	done <"${args_file}"
}

# Reads which profile is active for this machine.
# Outputs:
#   Writes the recorded name to stdout when one is set.
# Returns:
#   0 when a non-empty name was read, 1 otherwise.
read_profile() {
	local marker="${NIXFILES_PROFILE_MARKER}" name=""
	[[ -r ${marker} ]] || return 1
	read -r name <"${marker}" || true
	[[ -n ${name} ]] || return 1
	printf '%s\n' "${name}"
}

# Records the profile this machine should use from now on.
# Arguments:
#   $1 - profile name
# Outputs:
#   Writes a progress message to stdout.
write_profile() {
	local profile
	profile="${1:-}"
	[[ -n "${profile}" ]] || die "write_profile: 'profile name' may not be empty"

	local marker
	marker="${NIXFILES_PROFILE_MARKER}"
	mkdir --parents -- "$(dirname -- "${marker}")"
	printf '%s\n' "${profile}" >"${marker}"
	log "Recorded profile '${profile}' in ${marker}"
}

# Lists the profiles the repository defines.
# Arguments:
#   $1 - repository path
# Outputs:
#   Writes one profile name per line to stdout.
list_profiles() {
	local repo_path
	repo_path="${1:-}"
	[[ -n "${repo_path}" ]] || die "list_profiles: 'repository path' may not be empty"

	find "${repo_path}/home/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# Verifies a profile exists.
# Arguments:
#   $1 - repository path
#   $2 - profile name
# Returns:
#   0 when the profile exists; otherwise calls die and does not return.
require_profile() {
	local repo_path
	repo_path="${1:-}"
	[[ -n "${repo_path}" ]] || die "require_profile: 'repository path' may not be empty"

	local profile
	profile="${2:-}"
	[[ -n "${profile}" ]] || die "require_profile: 'profile name' may not be empty"

	[[ -d "${repo_path}/home/profiles/${profile}" ]] ||
		die "No such profile '${profile}'. Available: $(list_profiles "${repo_path}" | tr '\n' ' ')"
}

# Determines which profile applies, in precedence order:
# 1. Explicit profile name as an argument
# 2. Container detection
# 3. The recorded profile marker
# 4. "personal" as the safe default
# Container detection outranks the recorded marker because the marker lives in
# $HOME, and a dev container's $HOME is not the host's.
# Arguments:
#   $1 - explicit profile name; may be empty
# Outputs:
#   Writes the chosen profile name to stdout.
resolve_profile() {
	local requested_profile="${1:-}" recorded_profile=""

	if [[ -n ${requested_profile} ]]; then
		if is_container && [[ ${requested_profile} != "container" ]]; then
			warn "Inside a container, but '${requested_profile}' was requested."
		fi
		printf '%s\n' "${requested_profile}"
		return
	fi

	if is_container; then
		printf 'container\n'
		return
	fi

	if recorded_profile="$(read_profile)"; then
		printf '%s\n' "${recorded_profile}"
		return
	fi

	printf 'personal\n'
}
