#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
bin_name="$0"

# shellcheck disable=SC2034
declare -A PHASES_WITH_INDEX=()
# shellcheck disable=SC2034
declare -a COMMANDS_LIST=()

