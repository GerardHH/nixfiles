#shellcheck shell=bash
#
# Aggregates the shared shell libraries so a caller can source one file and
# get all of them. Source, never execute.

_lib="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
#shellcheck source=./paths.sh
source "${_lib}/paths.sh"
#shellcheck source=./log.sh
source "${_lib}/log.sh"
#shellcheck source=./profile.sh
source "${_lib}/profile.sh"
#shellcheck source=./nix.sh
source "${_lib}/nix.sh"
#shellcheck source=./preflight.sh
source "${_lib}/preflight.sh"
unset _lib
