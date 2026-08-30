#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_PATH="$(realpath -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname -- "$(dirname -- "${SCRIPT_PATH}")")"
# shellcheck source=../lib/common.sh
. "${REPO_DIR}/lib/common.sh"

PROFILE="${1:-$(detect_profile)}"
shift || true

load_nix
command -v nix >/dev/null || diagnose_missing_nix

require_git_tracked "${REPO_DIR}"
hm_switch "${REPO_DIR}" "${PROFILE}" "$@"
