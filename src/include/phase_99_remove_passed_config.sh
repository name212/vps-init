#!/usr/bin/env bash

set -Eeuo pipefail

export PROTECTED_PASSED_CONFIG_FILE=""

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_passed_config"]="99"


function set_passed_config_file() {
    PROTECTED_PASSED_CONFIG_FILE="${1:-}"
}

# shellcheck disable=SC2329
function phase_remove_passed_config_run() {
    if [ -z "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_info "Config not passed. Skip remove."
        return 0
    fi

    if [ ! -f "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_warn "Passed config '$PROTECTED_PASSED_CONFIG_FILE' not file. Skip"
        return 0
    fi

    if ! rm -fv "$PROTECTED_PASSED_CONFIG_FILE"; then
        echo_error "Passed config '$PROTECTED_PASSED_CONFIG_FILE' not removed!"
        return 1
    fi

    if [ ! -f "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_info "$PROTECTED_PASSED_CONFIG_FILE was removed!"
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