#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function validate_arg_func_declared() {
    local val="$1"
    local passed="$2"

    if ! call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_function_declared" "$val" "$passed"; then
        return 1
    fi
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_func_declared_optional() {
    local val="$1"
    local passed="$2"

    if ! call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "is_function_declared" "$val" "$passed"; then
        return 1
    fi
    
    echo -n "$val"
    return 0
}