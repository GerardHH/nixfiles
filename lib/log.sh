#shellcheck shell=bash
#
# Shared log helpers, should be sourced, never executed.

# Prints a progress message to stdout.
# Arguments:
#   $* - message text
# Outputs:
#   Writes the message to stdout, prefixed with a blue "==>".
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# Prints a non-fatal warning to stderr.
# Arguments:
#   $* - message text
# Outputs:
#   Writes the message to stderr, prefixed with a yellow "warn:".
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }

# Prints an error and terminates the calling script.
# Arguments:
#   $* - message text
# Outputs:
#   Writes the message to stderr, prefixed with a red "error:".
# Returns:
#   Does not return; exits 1.
die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}
