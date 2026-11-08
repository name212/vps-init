#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function validate_username() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_username_valid" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_username_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_username_valid" "$val" "$passed"
    return $?
}