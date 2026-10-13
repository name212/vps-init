#!/usr/bin/env bash

set -Eeuo pipefail

declare -a CONST_HELP_AGS=("-h" "--help")

# shellcheck disable=SC2329
function is_help_flag_set() {
    for ha in "${CONST_HELP_AGS[@]}"; do 
        if arg_flag_is_set "$ha" "" "$@"; then
            return 0
        fi
    done

    return 1
}

# shellcheck disable=SC2329
function echo_help_args_help() {
    local args_list=""

    for hah in "${CONST_HELP_AGS[@]}"; do
        if [ -z "$args_list" ]; then
            args_list="$hah"
            continue
        fi

        args_list="${args_list}|${hah}"
    done 

    echo -n "
    ${args_list}
      Show this help message."
}

