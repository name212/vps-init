#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_passed_config"]="99"

# shellcheck disable=SC2329
function phase_remove_passed_config_run() {
    local conf_file=""
    if ! conf_file="$(check_config_file_set_and_get)"; then
        echo_info "Config not passed. Skip remove."
        return 0
    fi

    if [ ! -f "$conf_file" ]; then
        echo_warn "Passed config '$conf_file' not file. Skip"
        return 0
    fi

    if ! rm -fv "$conf_file"; then
        echo_error "Passed config '$conf_file' not removed!"
        return 1
    fi

    if [ ! -f "$conf_file" ]; then
        echo_info "$conf_file was removed!"
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_remove_passed_config_help() {
    echo -n "
    Remove passed config file via --config arg for security reason.
    No Options.
"
}

# shellcheck disable=SC2329
function phase_remove_passed_config_disable_env() {
    echo -n "DISABLE_CLEANUP_PASSED_CONFIG"
}