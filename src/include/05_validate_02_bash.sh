#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function validate_arg_func_declared() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_function_declared" "$val" "$passed"
    return $?
}