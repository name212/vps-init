#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_VALIDATE_SHOULD_OPTIONAL="optional"
export CONST_VALIDATE_SHOULD_PASSED="passed"

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
function call_validate_fun() {
    local is_optional="$1"
    local validate_fun="$2"
    local val="$3"
    local passed="$4"

    if ! is_function_declared "$validate_fun"; then
        echo_error "Validation function '$validate_fun' is not declared"
        return 1
    fi

    if [[ "$is_optional" == "$CONST_VALIDATE_SHOULD_OPTIONAL" ]]; then
        if [[ "$passed" == "$CONST_ARG_NOT_PASSED" || "$val" == "" ]]; then
            echo -n ""
            return 0
        fi
    fi

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo_error "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo_error "Empty arg val"
        return 1 
    fi

    if ! val="$("$validate_fun" "$val")"; then
        return 1
    fi

    echo -n "$val"
    return 0
}
