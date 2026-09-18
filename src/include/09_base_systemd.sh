#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function systemd_disable_all() {
    for srv in "$@"; do
        if ! systemctl is-active "$srv"; then
            continue
        fi

        echo_green "systemd service $srv is active. Disable..."
        if ! systemctl disable --now "$srv"; then
            echo_red "Cannot disable $srv"
            return 1
        fi

        if ! systemctl stop "$srv"; then
            echo_red "Cannot stop $srv"
            return 1
        fi
    done

    return 0
}