#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function get_unix_timestamp() { 
    echo -n "$(date +%s)"
}

# shellcheck disable=SC2329
function is_timeout_exceeded() {
    local timeout="$1" 
    local start_time="$2" 
    
    # shellcheck disable=SC2155
    local cur_time="$(get_unix_timestamp)"

    if num_has_delta "$timeout" "$cur_time" "$start_time"; then
        return 0
    fi

    return 1
}