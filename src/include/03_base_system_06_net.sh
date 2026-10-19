#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function get_hostname() {
    local hst=""
    if ! hst="$(uname -n)"; then
        hst="host"
    fi

    echo -n "$hst"

    return 0
}

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
function check_is_mac_address() {
    if [[ "$val" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        echo -n "$(str_lower "$val")"
        return 0
    fi

    if [[ "$val" =~ ^([0-9A-Fa-f]{12})$ ]]; then
        local -a parts=()
        
        for (( i=0; i<${#val}; i+=2 )); do 
            parts+=("${val:i:2}"); 
        done
        
        # shellcheck disable=SC2155
        local res="$(join_args_with_separator ":" "${parts[@]}")"

        echo -n "$(str_lower "$res")"
        
        return 0
    fi

    echo_error "invalid MAC address $val"
    return 1
}
