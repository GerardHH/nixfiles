#!/usr/bin/env bash
#
# Reports, and applies, the root-owned fixes Home Manager cannot make.
#
# Usage:
#   host-setup.sh [action]
#
# Arguments:
#   action - "check" to report what is missing, "apply" to install it.
#            Defaults to "check". "apply" prompts for sudo.
#
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
#
# Returns:
#   0 when every fix is in place; non-zero when one is missing or could not
#   be applied.

set -o errexit -o nounset -o pipefail

#shellcheck source=./../lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

ACTION="${1:-check}"

case "${ACTION}" in
check)
	check_host_fixes
	;;
apply)
	apply_bwrap_profile
	;;
*)
	die "Unknown action '${ACTION}'. Use 'check' or 'apply'."
	;;
esac
