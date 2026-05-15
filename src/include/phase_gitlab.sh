#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function prepare_gitlab_runner_service() {
    local service_name="$1"
    local username="$2"

    local exec_str=""

    if systemctl is-active "$service_name"; then
        if ! exec_str="$(systemctl show "$service_name" --no-pager -p ExecStart)"; then
            echo_red "Cannot get exec string for gitlab service"
            return 1
        fi
    else 
        echo_green "gitlab service not active!"
    fi

    if [ -z "$exec_str" ]; then
        echo_red "exec string for gitlab service is empty"
        return 1
    fi

    if grep -q "user $username" <<<"$exec_str"; then
        echo_green "Runner $runner_name already will run with user!"
        if ! systemctl daemon-reload; then
            echo_red "Cannot run daemon reload!"
            return 1
        fi
        return 0
    fi

    echo_green "Gitlab service probably has not user: ${exec_str}"

    if ! ask_user "Do you want to reinstall service?"; then
        echo_red "Disallow reinstall runner service!"
        return 1
    fi

    echo_green "Start reinstall gitlab service..."

    if ! sudo systemctl stop "$service_name"; then
        echo_red "Cannot stop gitlab runner service!"
        return 1
    fi

    echo_green "Start uninstall gitlab service..."

    if ! gitlab-runner uninstall; then
        echo_red "Cannot uninstall gitlab runner service!"
        return 1
    fi

    local install_args=(
        "--service" 
        "$service_name"
        "--user"
        "$username"
        "--working-directory" 
        "/home/$username"
    )

    echo_green "Start install gitlab service..."

    if ! gitlab-runner install "${install_args[@]}"; then
        echo_red "Cannot install gitlab runner service!"
        return 1
    fi

    echo_green "Reload systemd..."

    if ! systemctl daemon-reload; then
        echo_red "Cannot run daemon reload!"
        return 1
    fi

    echo_green "Start gitlab service..."

    if ! systemctl start "$service_name"; then
        echo_red "Cannot run gitlab service!"
        return 1
    fi

    echo_green "Enable gitlab service..."

    if ! systemctl enable "$service_name"; then
        echo_red "Cannot enable gitlab service!"
        return 1
    fi
    
    echo_green "Gitlab service reinstalled with new user!"
}

# shellcheck disable=SC2329
function install_gitlab_runner() {
    local not_ask="$1"

    echo_green "Install gitlab runner..."

    echo_green "Create user for runner..."

    local username="gitlab-runner"
    
    if ! add_user "$username"; then
        return 1
    fi

    local package="gitlab-runner"

    if ! check_packages_installed "$package"; then
        echo_green "Prepare gitlab apt repository..."

        local url="https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh"

        if ! download_script_and_run "$url" "$not_ask"; then
            return 1
        fi

        echo_green "Install gitlab runner package ${package}..."

        if ! install_packages "$package"; then
            echo_red "gitlab runner not installed!"
            return 1
        fi
    else
        echo_green "gitlab runner already installed!"
    fi

    echo_green "Allow gitlab user for run docker..."

    if ! add_user_to_group "$username" "docker"; then
        return 1
    fi

    echo_green "Restart gitlab runner service..."

    local service_name="gitlab-runner.service"

    if ! prepare_gitlab_runner_service "$service_name" "$username"; then
        return 1
    fi

    if systemctl is-active "$service_name"; then
        echo_green "Restart gitlab runner service..."
        if ! systemctl restart gitlab-runner.service; then
            echo_red "Cannot restart gitlab runner service!"
            return 1
        fi
    fi

    echo_green "gitlab runner installed!"
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