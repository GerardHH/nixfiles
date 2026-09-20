#shellcheck shell=bash
#
# Credentials and host state the lely profile needs. Sourced by
# require_profile_prerequisites.

LELY_SECRETS_DIR="${HOME}/git/lely/nixfiles-secrets"
LELY_SSH_KEY="${HOME}/.ssh/gitlab-lely"

# lely imports ../personal in default.nix, so it deploys everything personal
# deploys and needs everything personal checks. The Nix imports compose but
# the preflight hooks do not, so the inheritance is spelled out here.
inherit_profile_prerequisites personal

NIXFILES_AGE_IDENTITIES+=(lely)

# Private key is not tracked, check if it exists and is valid.
require_ssh_key "${LELY_SSH_KEY}" \
	"Restore it from your password manager, or generate a new pair and register the public half with server"

# Public half is not tracked, generate from private half.
derive_ssh_public_key "${LELY_SSH_KEY}"

require_secrets_checkout "${LELY_SECRETS_DIR}" \
	"secrets/artifactory.yaml" \
	"secrets/git.yaml" \
	"secrets/ssh.yaml" \
	"secrets/ssh-keys"
