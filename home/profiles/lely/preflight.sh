#shellcheck shell=bash
#
# Credentials the lely profile needs. Sourced by require_profile_prerequisites.

LELY_SECRETS_DIR="${HOME}/git/lely/nixfiles-secrets"

# Lists personal too: lely imports ../personal in default.nix, so it deploys
# every secret personal deploys, and needs the identity that decrypts them.
require_age_keys personal lely

require_secrets_checkout "${LELY_SECRETS_DIR}" \
	"secrets/git.yaml" \
	"secrets/ssh.yaml"
