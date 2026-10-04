#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function is_function_declared() {
    local fun="${1:-}"

    if [ -z "$fun" ]; then
        echo_error "Function is not passed"
        return 1
    fi

    if ! declare -F "$fun" > /dev/null; then
        echo_error "Function '$fun' is not declared"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function trap_all() {
    local fn="${1:-}"
    
    if [ -z "$fn" ]; then
        return 0
    fi

    if ! is_function_declared "$fn"; then
        echo_error "Function '$fn' is not declared for trap"
    fi

    # shellcheck disable=SC2086
    trap $fn EXIT
    # shellcheck disable=SC2086
    trap $fn SIGINT
    # shellcheck disable=SC2086
    trap $fn SIGTERM

    echo_debug "Set trap function '$fn' for EXIT SIGINT SIGTERM"
}

# shellcheck disable=SC2329
function get_env_value_or_default() {
    local var_name="$1"
    local default_val="${2-}"

    if ! [[ -v "$var_name" ]]; then
        echo -n "$default_val"
        return 0
    fi

    echo -n "${!var_name}"
    return 0
}
