#!/usr/bin/env bash

set -Eeuo pipefail

COMMANDS_LIST+=("gitlab_register_runner")

export CONST_GITLAB_SERVICE_NAME="gitlab-runner.service"

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_run() {
    if ! command -v gitlab-runner &> /dev/null; then
        echo_error "gitlab runner is not installed!"
        echo_error "Please init server or install with --phase gitlab first."
        return 1
    fi

    if ! systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_error "gitlab runner service is not active!"
        echo_error "Please init server or install with --phase gitlab first."
        return 1
    fi

    local runner_config=""

    if ! runner_config="$(extract_argument "--gitlab-runner-config" "GITLAB_RUNNER_CONFIG" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_error "Gitlab runner config"
        return 1
    fi

    if [ -n "$runner_config" ]; then
        echo_info "Load runner config $runner_config"
        # shellcheck disable=SC1090
        set -a && source "$runner_config" && set +a
    fi

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

    if [ -n "$errors" ]; then
        echo_error "$errors"
        return 1
    fi

    local executor="shell"
    if [ -n "${GITLAB_RUNNER_EXECUTOR-}" ]; then 
        executor="${GITLAB_RUNNER_EXECUTOR}"
    fi

    local runners=""
    if ! runners="$(gitlab-runner list -c /etc/gitlab-runner/config.toml)"; then
        echo_error "Cannot list runners!"
        return 1
    fi

    local runner_name="$GITLAB_RUNNER_DESC"

    if grep -q "$runner_name" <<<"$runners"; then
        echo_info "Runner $runner_name already registered!"
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
        "--executor" 
        "$executor"
    )

    if ! gitlab-runner register "${register_args[@]}"; then
        echo_error "Cannot register runner ${runner_name}!"
        return 1
    fi
    
    echo_info "Runner ${runner_name} registered!"
}

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_help() {
    echo -n "
    Register gitlab runner.
    Options:
      --gitlab-runner-config PATH
         Path to configuration to register runner.
         Should be sh script with export next variables:
           GITLAB_RUNNER_URL       - url to register gitlab runner.
           GITLAB_RUNNER_TOKEN     - token to register runner
           GITLAB_RUNNER_DESC      - name or description of new runner
           GITLAB_RUNNER_EXECUTOR  - executor of runner. Default shell
         All parameters is required.
         Can be provided with env GITLAB_RUNNER_CONFIG
    Also you can provide envs without config.
"
}