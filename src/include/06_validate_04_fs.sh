#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function check_file_is_not_empty() {
    local val="$1"

    local real=""

    if ! real="$(realpath "$val")"; then
        echo_error "Cannot extract real path for '$val'"
        return 1
    fi

    if [ ! -f "$real" ]; then
        echo_error "'$val' is not file!"
        return 1
    fi

    if [ ! -s "$real" ]; then
        echo_error "'$val' is empty file!"
        return 1
    fi

    echo -n "$real"
    return 0
}

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