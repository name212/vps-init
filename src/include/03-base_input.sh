#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function ask_user() {
    local prompt="$1"
    local not_ask="${2-no}"

    if [[ "$not_ask" == "$CONST_FLAG_SET" ]]; then
        return 0
    fi

    local answer=""

    read -p "${prompt} [y/n]: " answer

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}