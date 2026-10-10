#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function validate_arg_not_empty_file() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_file_is_not_empty" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_not_empty_file_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_file_is_not_empty" "$val" "$passed"
    return $?
}