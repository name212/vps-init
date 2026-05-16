#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["hostname"]="04"

# shellcheck disable=SC2329
function phase_hostname_run() {
    local new_hostname=""

    if ! new_hostname="$(extract_argument "--new-hostname" "NEW_HOSTNAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_red "New hostname: $new_hostname"
        return 1
    fi

    echo_green "Prepare hostname..."

    local cur_hostanme=""
    if ! cur_hostanme="$(hostnamectl hostname)"; then
        echo_red "Cannot get current host name!"
        return 1
    fi

    if [[ "$new_hostname" == "$cur_hostanme" ]]; then
        echo_green "Hostname already set to $new_hostname!"
    else
        if ! hostnamectl set-hostname "$new_hostname"; then
            echo_red "Cannot set hostname to $new_hostname!"
            return 1
        fi
    fi

    local hosts_file="/etc/hosts"
    local tab=$'\t'
    local hostname_hosts="127.0.1.1${tab}${new_hostname}"

    if grep -q "$hostname_hosts" "$hosts_file"; then
        echo_green "$new_hostname added to $hosts_file for alias to 127.0.1.1"
    else
        echo_green "Prepare hostname. Add new hostname for alias 127.0.1.1 to ${hosts_file} ..."

        {
            echo ""
            echo "# local for ${new_hostname}"
            echo "$hostname_hosts"
            echo ""
        } >> "$hosts_file"

        echo_green "--- New $hosts_file ---"
        cat "$hosts_file"
        echo_green "--- End file ---"
    fi

    echo_green "Hostname changed!"

    return 0
}

# shellcheck disable=SC2329
function phase_hostname_help() {
    echo "
    Change hostname
    Options:
      --new-hostname hostaname
        Set new hostname.
        Can be provided with env NEW_HOSTNAME
"
}

# shellcheck disable=SC2329
function phase_hostname_disable_env() {
    echo -n "DISABLE_HOSTNAME"
}