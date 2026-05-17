#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["werf"]="82"

# shellcheck disable=SC2329
function phase_werf_run() {
    echo_green "Install werf..."

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    if command -v werf &> /dev/null; then
        echo_green "Werf already installed!"
        return 0
    fi

    local url="https://werf.io/install.sh"

    if ! download_script_and_run "$url" "$not_ask" "--ci"; then
        return 1
    fi

    echo_green "Werf installed!"
}

# shellcheck disable=SC2329
function phase_werf_help() {
    echo -n "
    Install Werf
      No options.
"
}

# shellcheck disable=SC2329
function phase_werf_disable_env() {
    echo -n "DISABLE_WERF"
}