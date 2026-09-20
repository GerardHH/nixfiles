#shellcheck shell=bash
#
# Credentials and host state the personal profile needs. Sourced by
# require_profile_prerequisites.

# Declared rather than assembled here: a profile inheriting this one adds its
# own identities, and require_profile_prerequisites writes them all into the
# single file sops reads, once, after the whole chain has run.
NIXFILES_AGE_IDENTITIES+=(personal)

# Claude Code runs here and sandboxes every shell command with bwrap.
check_bwrap_sandbox
