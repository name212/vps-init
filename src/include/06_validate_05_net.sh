#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function check_is_number_port() {
    local port="$1"

    if ! port="$(check_is_number "$port" "$CONST_ARG_PASSED")"; then
        echo_error "Port is not number"
        return 1
    fi

    if [ "$port" -gt "0" ] && [ "$port" -le "65535" ]; then
        echo -n "$port"
        return 0
    fi

    echo_error "Port '$port' should be >= 1 and <=  65535"
    return 1
}

# shellcheck disable=SC2329
function validate_arg_port() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_number_port" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_port_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_number_port" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function check_is_ipv4() {
    local val="$1"
    local regexp='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if [[ "$val" =~ $regexp ]]; then
        echo -n "$val"
        return 0
    fi 

    echo_error "Incorrect IPv4 '$val'"
    return 1
}

# shellcheck disable=SC2329
function validate_arg_ipv4() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_ipv4" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_ipv4_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_ipv4" "$val" "$passed"
    return $?
}