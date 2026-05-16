#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["aliases"]="99"

# shellcheck disable=SC2329
function phase_aliases_run() {
    echo_green "Add aliases..."

    local content=""
    content=$(cat <<EOF
alias h='history | grep -i'
alias psf='ps aux | grep -i'
EOF
    )

    echo "$content" > /etc/profile.d/099-additional-aliases.sh

    echo_green "Aliases added!"
}

# shellcheck disable=SC2329
function phase_aliases_help() {
    echo -n "
    Add aditional aliases
    No Options.
"
}

# shellcheck disable=SC2329
function phase_aliases_disable_env() {
    echo -n "DISABLE_ALIASES"
}

