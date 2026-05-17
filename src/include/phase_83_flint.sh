#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["flint"]="83"

# shellcheck disable=SC2329
function phase_flint_run() {
    echo_green "Install flint..."

    if command -v flint &> /dev/null; then
        echo "Flint already installed!"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local url="https://tuf.flint.flant.ru/install.sh"

    local script_args=(
        "--version"
        "2"
        "--channel"
        "stable"
    )

    if ! download_script_and_run "$url" "$not_ask" "${script_args[@]}"; then
        return 1
    fi

    echo_green "Flint installed!"
}

# shellcheck disable=SC2329
function phase_flint_help() {
    echo -n "
    Install flint.
      No options.
"
}

# shellcheck disable=SC2329
function phase_flint_disable_env() {
    echo -n "DISABLE_FLINT"
}