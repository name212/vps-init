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

    echo_error "Port '$port' should be >= 1 and <= 65535"
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
    local val="$1"

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

    echo_error "Invalid MAC address $val"
    return 1
}

# shellcheck disable=SC2329
function get_net_interfaces_from_kernel() {
    local dest_arr_name="$1"

    if ! is_array_var "$dest_arr_name"; then
        echo_error "Destination interfaces array name '$dest_arr_name' is not array"
        return 1
    fi

    local net_dev_out=""
    if ! net_dev_out="$(cat /proc/net/dev)"; then
        echo_error "Cannot get interfaces from kernel"
        return 1
    fi

    local only_interfaces_out=""
    if ! only_interfaces_out="$(echo "$net_dev_out" | grep -oP " *[a-zA-Z0-9]+:")"; then
        echo_error "Cannot grep interfaces names"
        return 1
    fi

    function __trim_kernel_interfaces() {
        local iface_name="$1"
        # shellcheck disable=SC2155
        local trimmed="$(trim_spaces "$iface_name")"
        echo -n "$(trim_by_string_right ":" "1" "$trimmed")"
        return 0
    }

    local -a __get_ifaces_split=()
    if ! split_by_new_line "__get_ifaces_split" "$only_interfaces_out" "__trim_kernel_interfaces"; then
        echo_error "Cannot split interfaces out by new line"
        return 1
    fi

    local -n __get_interfaces_dest="$dest_arr_name"

    local indx="0"
    for iface in "${__get_ifaces_split[@]}"; do
        if str_empty "$iface"; then
            continue
        fi

        __get_interfaces_dest["$indx"]="$iface"
        ((indx++)) || true
    done

    return 0
}
