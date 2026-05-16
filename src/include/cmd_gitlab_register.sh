#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function phase_gitlab_disable_env() {
    echo -n "DISABLE_GITLAB"
}

# shellcheck disable=SC2329
function register_gitlab_runner() {
    local runner_config="$1"

    if [ ! -f "$runner_config" ]; then
        echo_red "$runner_config file not exists!"
        return 1
    fi

    # shellcheck disable=SC2046
    export $(grep -v '^#' "$runner_config" | xargs -d '\n')

    local errors=""

    if [ -z "$GITLAB_RUNNER_URL" ]; then 
        errors="${errors} GITLAB_RUNNER_URL not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_TOKEN" ]; then 
        errors="${errors} GITLAB_RUNNER_TOKEN not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_DESC" ]; then 
        errors="${errors} GITLAB_RUNNER_DESC not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_TAGS" ]; then 
        errors="${errors} GITLAB_RUNNER_TAGS not provided in config"
    fi

    if [ -n "$errors" ]; then
        echo_red "$errors"
        return 1
    fi

    local runners=""
    if ! runners="$(gitlab-runner list -c /etc/gitlab-runner/config.toml)"; then
        echo_red "Cannot list runners!"
        return 1
    fi

    local runner_name="$GITLAB_RUNNER_DESC"

    if grep -q "$runner_name" <<<"$runners"; then
        echo_green "Runner $runner_name already registered!"
        return 0
    fi

    local register_args=(
        "--non-interactive"
        "--url" 
        "$GITLAB_RUNNER_URL"
        "--token" 
        "$GITLAB_RUNNER_TOKEN"
        "--description" 
        "$runner_name"
        "--tag-list"
        "$GITLAB_RUNNER_TAGS"
        "--executor" 
        "shell"
    )

    if ! gitlab-runner register "${register_args[@]}"; then
        echo_red "Cannot register runner ${runner_name}!"
        return 1
    fi
    
    echo_green "Runner ${runner_name} registered!"
}