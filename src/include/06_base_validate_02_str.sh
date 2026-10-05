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

# shellcheck disable=SC2329
function is_number_positive() {
    local val="$1"
    local have_zero="${2:-}"

    if ! val="$(check_is_number "$val")"; then
        return 1
    fi

    local err_num="1"

    if [ -n "$have_zero" ]; then
        err_num="0"
        if [ "$val" -ge "0" ]; then
            echo -n "$val"
            return 0
        fi
    else 
        err_num="1"
        if [ "$val" -gt "0" ]; then
            echo -n "$val"
            return 0
        fi
    fi

    echo_error "Number '$val' < $err_num"
    return 0
}

# shellcheck disable=SC2329
function is_number_positive_or_zero() {
    is_number_positive "$1" "true"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_positive() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_number_positive" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_positive_or_zero() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_number_positive_or_zero" "$val" "$passed"
    return $?
}