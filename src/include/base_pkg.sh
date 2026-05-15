#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function install_packages() {
    echo_green "Install apt packages $* ..."
    if ! apt update; then 
        echo_red "Cannot run apt update!"
        return 1
    fi

    if ! apt install -y "$@"; then
        echo_red "Cannot run apt install!"
        return 1
    fi

    echo_green "Packages $* installed!"
}

# shellcheck disable=SC2329
function check_packages_installed() {
    local all="true"
    while [[ $# -gt 0 ]]; do
        local name="$1"
        if ! dpkg-query -s "$name" &> /dev/null; then
            echo_green "$name not installed..."
            all="false"
        fi
        shift
    done

    if [[ "$all" == "false" ]]; then
        return 1
    fi
    
    return 0
}