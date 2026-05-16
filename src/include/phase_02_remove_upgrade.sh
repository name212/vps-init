#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_upgrade"]="02"

# shellcheck disable=SC2329
function phase_remove_upgrade_run() {
    echo_green "Remove unattended upgrades..."

    if ! remove_packages "unattended-upgrades"; then
        return 1 
    fi

    local -a timers=("apt-daily.timer" "apt-daily-upgrade.timer")

    echo_green "Stop and disable timers ${timers[*]} ..."
    
    if ! systemctl disable "${timers[@]}"; then 
        echo_red "Cannot disable timers"
        return 1
    fi

    if ! systemctl stop "${timers[@]}"; then 
        echo_red "Cannot stop timers"
        return 1
    fi

    echo_green "Unattended upgrades removed!"
    return 0
}

# shellcheck disable=SC2329
function phase_remove_upgrade_help() {
    echo -n "
    Remove unattended upgrades.
    No options.
"
}

# shellcheck disable=SC2329
function phase_remove_upgrade_disable_env() {
    echo -n "DISABLE_REMOVE_UPGRADE"
}