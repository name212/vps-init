#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["upgrade_pkgs"]="01"

# shellcheck disable=SC2329
function phase_upgrade_pkgs_run() {
    echo_green "Upgrade packages..."

    if ! upgrade_all_packages; then
        echo_red "Packages not upgraded"
        return 1
    fi

    echo_green "All packages upgraded!"
}

# shellcheck disable=SC2329
function phase_upgrade_pkgs_help() {
    echo -n "
    Upgrade all packages before run.
    No options.
"
}

# shellcheck disable=SC2329
function phase_upgrade_pkgs_disable_env() {
    echo -n "DISABLE_UPGRADE_ALL"
}