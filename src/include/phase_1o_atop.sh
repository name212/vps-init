#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["atop"]="10"

# shellcheck disable=SC2329
function phase_atop_run() {
    echo_green "Disable atop..."

    if ! systemd_disable_all "atop.service" "atop-rotate.timer" "atopacct.service"; then
        return 1
    fi

    echo_green "Atop disabled!"

    return 0 
}

# shellcheck disable=SC2329
function phase_atop_help() {
    echo -n "
    Disable atop services.
    No options. 
"
 }

# shellcheck disable=SC2329
function phase_atop_disable_env() {
    echo -n "DISABLE_ATOP"
}