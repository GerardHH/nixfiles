#shellcheck shell=bash
#
# Checks on root-owned host state that Home Manager cannot manage. Source,
# never execute.
#
# Both targets are plain Ubuntu and Home Manager runs unprivileged, so nothing
# outside $HOME can be expressed as a module. The fixes themselves live in
# host/ as data plus an apply step in bin/host-setup.sh; this file only
# supplies the checks that notice when one is missing, and like preflight.sh
# it knows no profile by name.

#shellcheck source=./log.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/log.sh"
#shellcheck source=./paths.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

# The AppArmor profile that lets bwrap keep its capabilities, and the binary it
# is anchored to. AppArmor matches on an absolute path, so the profile targets
# Ubuntu's bubblewrap package rather than whatever bwrap happens to be first on
# PATH.
NIXFILES_BWRAP_PATH="/usr/bin/bwrap"
NIXFILES_BWRAP_PROFILE_SRC="${NIXFILES_HOST_DIR}/apparmor.d/bwrap"
NIXFILES_BWRAP_PROFILE_DST="/etc/apparmor.d/bwrap"

# Reports whether AppArmor strips capabilities from unprivileged user
# namespaces, as Ubuntu 24.04 does by default.
# Returns:
#   0 when the restriction is active, 1 otherwise.
apparmor_restricts_userns() {
	local sysctl="/proc/sys/kernel/apparmor_restrict_unprivileged_userns"
	[[ -r ${sysctl} ]] || return 1
	[[ "$(cat -- "${sysctl}")" == "1" ]]
}

# Every bwrap an agent CLI might exec: Ubuntu's, plus whatever bubblewrap Nix
# has realised in the store. Claude Code runs the store copy by absolute path,
# so it never reaches PATH, and a check against /usr/bin/bwrap alone reports
# success while every sandboxed command still fails.
# Outputs:
#   Writes one executable path per line to stdout.
bwrap_paths() {
	local path
	for path in "${NIXFILES_BWRAP_PATH}" /nix/store/*-bubblewrap-*/bin/bwrap; do
		if [[ -x ${path} ]]; then
			printf '%s\n' "${path}"
		fi
	done
	return 0
}

# Reports whether bwrap can build the sandbox an agent CLI needs.
# Tests the behaviour rather than looking for the profile file: the namespace
# built here is the one Claude Code's sandbox builds, so this stays honest if
# Ubuntu changes the mechanism again, where a test for the file would report
# success while every command still failed.
# Uses the absolute path rather than whatever is first on PATH, because the
# AppArmor profile attaches to that path: testing anything else would report a
# failure that installing the profile cannot fix.
# Globals:
#   NIXFILES_BWRAP_PATH - read
# Returns:
#   0 when a full sandbox can be created, 1 otherwise.
bwrap_sandbox_works() {
	local path found=0
	while IFS= read -r path; do
		found=1
		"${path}" --unshare-all --ro-bind / / --dev /dev -- true >/dev/null 2>&1 ||
			return 1
	done < <(bwrap_paths)
	((found > 0))
}

# Explains why bwrap cannot sandbox and how to fix it.
# Arguments:
#   $1 - one line on what was observed
# Globals:
#   NIXFILES_BIN_DIR, NIXFILES_HOST_DIR - read
# Outputs:
#   Writes the explanation to stderr.
warn_missing_bwrap_profile() {
	warn "${1}"
	cat >&2 <<EOF

  Agent CLIs sandbox their shell commands with bwrap. Ubuntu 24.04 sets
  kernel.apparmor_restrict_unprivileged_userns=1, and a binary with no
  AppArmor profile of its own is transitioned into
  /etc/apparmor.d/unprivileged_userns, which opens with 'audit deny
  capability'. bwrap still gets its namespaces but loses CAP_NET_ADMIN and
  CAP_SYS_ADMIN inside them, so it can neither bring up loopback nor
  bind-mount, and dies with:

    bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted

  Claude Code is configured with failIfUnavailable and without
  allowUnsandboxedCommands, so there is no fallback: the sandbox failing
  means every shell command fails.

  Home Manager runs unprivileged and cannot write /etc/apparmor.d. Apply the
  profile by hand, once per machine:

    ${NIXFILES_BIN_DIR}/host-setup.sh apply

  Background, and what that profile costs: ${NIXFILES_HOST_DIR}/README.md
EOF
}

# Install bwrap if missing.
# Globals:
#   NIXFILES_BWRAP_PATH - read
# Outputs:
#   Writes progress to stdout.
# Returns:
#   0 when bwrap is installed and/or pressent; otherwise calls die and does not return.
require_ubuntu_bubblewrap() {
	if [[ -x ${NIXFILES_BWRAP_PATH} ]]; then
		return 0
	fi

	log "Installing bubblewrap from apt"
	sudo apt-get install --yes bubblewrap

	[[ -x ${NIXFILES_BWRAP_PATH} ]] ||
		die "apt installed bubblewrap but ${NIXFILES_BWRAP_PATH} is still missing."
}

# Installs the bwrap AppArmor profile and loads it.
# Globals:
#   NIXFILES_BWRAP_PROFILE_SRC, NIXFILES_BWRAP_PROFILE_DST - read
# Outputs:
#   Writes progress to stdout.
# Returns:
#   0 when bwrap can sandbox afterwards; otherwise calls die and does not return.
apply_bwrap_profile() {
	if ! apparmor_restricts_userns; then
		log "AppArmor does not restrict user namespaces here; nothing to apply."
		return 0
	fi

	if bwrap_sandbox_works; then
		log "bwrap already sandboxes; the profile is in place."
		return 0
	fi

	require_ubuntu_bubblewrap

	[[ -r ${NIXFILES_BWRAP_PROFILE_SRC} ]] ||
		die "No profile to install at ${NIXFILES_BWRAP_PROFILE_SRC}."

	log "Installing ${NIXFILES_BWRAP_PROFILE_DST}"
	sudo install --mode=644 --owner=root --group=root \
		-- "${NIXFILES_BWRAP_PROFILE_SRC}" "${NIXFILES_BWRAP_PROFILE_DST}"

	log "Loading the profile"
	sudo apparmor_parser --replace --write-cache "${NIXFILES_BWRAP_PROFILE_DST}"

	bwrap_sandbox_works ||
		die "bwrap still cannot sandbox. Look for DENIED lines in: sudo dmesg | grep apparmor"

	log "bwrap sandbox works."
}

# Reports whether the bwrap fix is in place, explaining when it is not.
# Globals:
#   NIXFILES_BWRAP_PATH - read
# Outputs:
#   Writes an explanation to stderr when the sandbox is unavailable.
# Returns:
#   0 when nothing is wrong, 1 when the fix is missing.
bwrap_fix_ok() {
	apparmor_restricts_userns || return 0

	if [[ ! -x ${NIXFILES_BWRAP_PATH} ]]; then
		warn_missing_bwrap_profile "${NIXFILES_BWRAP_PATH} is not installed, so agent CLIs cannot sandbox."
		return 1
	fi

	local resolved
	resolved="$(command -v bwrap || true)"
	if [[ -n ${resolved} && ${resolved} != "${NIXFILES_BWRAP_PATH}" ]]; then
		warn "bwrap on PATH resolves to ${resolved}, but the profile covers ${NIXFILES_BWRAP_PATH}."
	fi

	if ! bwrap_sandbox_works; then
		warn_missing_bwrap_profile "bwrap cannot create a sandbox, so agent CLIs will fail every command."
		return 1
	fi

	return 0
}

# Warns when the bwrap fix is missing, without failing the activation.
# Separate from bwrap_fix_ok because preflight hooks run under errexit: a
# non-zero return would abort a switch over a tool that is merely degraded,
# which is the wrong trade.
# Outputs:
#   Writes an explanation to stderr when the sandbox is unavailable.
# Returns:
#   Always 0.
check_bwrap_sandbox() {
	bwrap_fix_ok || true
}

# Reports the state of every host fix.
# Outputs:
#   Writes explanations to stderr for anything missing.
# Returns:
#   0 when every fix is in place, 1 otherwise.
check_host_fixes() {
	local failed=0

	bwrap_fix_ok || failed=1

	if ((failed > 0)); then
		return 1
	fi

	log "All host fixes are in place."
}
