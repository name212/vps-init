#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["gitlab"]="80"

# shellcheck disable=SC2329
function gitlab_prepare_runner_service() {
    local service_name="$1"
    local username="$2"
    local not_ask="${3-no}"

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
        echo_green "Runner $service_name already will run with user!"
        if ! systemctl daemon-reload; then
            echo_red "Cannot run daemon reload!"
            return 1
        fi
        return 0
    fi

    echo_green "Gitlab service probably has not user: ${exec_str}"

    if ! ask_user "Do you want to reinstall service?" "$not_ask"; then
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
function phase_gitlab_run() {
    echo_green "Install gitlab runner..."

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Create user for runner..."

    local username="gitlab-runner"
    
    if ! add_user "$username" "$CONST_REMOVE_PASSWORD" "$not_ask" ""; then
        return 1
    fi

    local user_home=""
    if ! user_home="$(get_user_home "$username")"; then 
        echo_red "$user_home"
        return 1
    fi

    local bash_logout_file="${user_home}/.bash_logout"

    if [ -f "$bash_logout_file" ]; then
        echo_green "Remove $bash_logout_file ..."
        if ! delete_file "$bash_logout_file"; then
            return 1
        fi
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

    if ! gitlab_prepare_runner_service "$CONST_GITLAB_SERVICE_NAME" "$username" "$not_ask"; then
        return 1
    fi

    if systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_green "Restart gitlab runner service..."
        if ! systemctl restart gitlab-runner.service; then
            echo_red "Cannot restart gitlab runner service!"
            return 1
        fi
    fi

    echo_green "gitlab runner installed!"
}

# shellcheck disable=SC2329
function phase_gitlab_help() {
    echo -n "
    Install and prepare gitlab runner.
    No Options.
"
}

# shellcheck disable=SC2329
function phase_gitlab_disable_env() {
    echo -n "DISABLE_GITLAB"
}
