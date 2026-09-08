#shellcheck shell=bash
#
# Canonical repository paths. Source, never execute.

#shellcheck disable=SC2034

# Directory holding the shared shell libraries.
NIXFILES_LIB_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"

# Root of the nixfiles checkout, holding flake.nix.
NIXFILES_REPO_DIR="$(dirname -- "${NIXFILES_LIB_DIR}")"

# Executable tools. Added to PATH by home.sessionPath in common.nix.
NIXFILES_BIN_DIR="${NIXFILES_REPO_DIR}/bin"

# Home Manager modules and the profiles that compose them.
NIXFILES_HOME_DIR="${NIXFILES_REPO_DIR}/home"
NIXFILES_MODULES_DIR="${NIXFILES_HOME_DIR}/modules"
NIXFILES_PROFILES_DIR="${NIXFILES_HOME_DIR}/profiles"

# Encrypted secrets, matched by the .sops.yaml creation rule.
NIXFILES_SECRETS_DIR="${NIXFILES_REPO_DIR}/secrets"
