#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function get_hostname() {
    local hst=""
    if ! hst="$(uname -n)"; then
        hst="host"
    fi

    echo -n "$hst"

    return 0
}