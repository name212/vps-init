#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["hostname"]="03"

# shellcheck disable=SC2329
function phase_hostname_run() {
    if [[ "${DISABLE_HOSTNAME-no}" == "true" ]]; then
        echo_yellow "Skip change sshd!"
        return 0
    fi

    local new_hostname="${SET_HOSTNAME-}"
    if [ -z "$new_hostname" ]; then
        echo_red "New hostname not passed!"
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
        return 0
    fi

    if ! hostnamectl set-hostname "$new_hostname"; then
        echo_red "Cannot set hostname to $new_hostname!"
        return 1
    fi

    echo_green "Prepare hostname. Change /etc/hosts..."
    local tab=$'\t'

    {
        echo ""
        echo "# local for ${new_hostname}"
        echo "127.0.0.1${tab}${new_hostname}"
        echo ""
    } >> "/etc/hosts"

    echo_green "--- New /etc/hosts ---"
    cat "/etc/hosts"
    echo_green "--- End file ---"

    return 0
}

# shellcheck disable=SC2329
function phase_hostname_help() {
    echo "
    Change hostname
    Options:
      --hostname hostaname
        Set new hostname.
        Can be provided with env SET_HOSTNAME
"
}

# shellcheck disable=SC2329
function phase_hostname_disable_env() {
    echo -n "DISABLE_HOSTNAME"
}