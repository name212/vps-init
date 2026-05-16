#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["aliases"]="99"

# shellcheck disable=SC2329
function phase_aliases_run() {
    if [[ "${DISABLE_ALIASES-no}" == "true" ]]; then
        echo_yellow "Skip add aliases!"
        return 0
    fi

    cat << EOF > /etc/profile.d/099-additional-aliases.sh
alias h='history | grep -i'
alias psf='ps aux | grep -i'
EOF
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

