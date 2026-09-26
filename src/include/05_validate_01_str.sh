#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function validate_arg_not_empty() {
    local val="$1"
    local passed="$2"

    function __dummy_validate() {
        echo -n "$1"
    }

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "__dummy_validate" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function check_is_number() {
    local val="$1"

    if ! [[ $val =~ ^-?[0-9]+$ ]]; then
        echo_error "'$val' is not number!"
        return 1
    fi

    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_number() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_number" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_number" "$val" "$passed"
    return $?
}