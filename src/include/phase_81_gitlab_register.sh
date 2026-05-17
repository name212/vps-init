#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["gitlab_register"]="81"

# shellcheck disable=SC2329
function phase_gitlab_register_run() {
    echo_green "Gitlab register runner..."
    if ! cmd_gitlab_register_runner_run "$@"; then
        return 1
    fi
    echo_green "Gitlab runner registered!"
    return 0
}

# shellcheck disable=SC2329
function phase_gitlab_register_help() {
    cmd_gitlab_register_runner_help
}

# shellcheck disable=SC2329
function phase_gitlab_register_disable_env() {
    echo -n "DISABLE_GITLAB_REGISTER_RUNNER"
}
