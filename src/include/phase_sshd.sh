#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="03"

# shellcheck disable=SC2329
function sshd_verify_and_restart() {
    local setting="${1,,}"

    if ! sshd -t; then
        echo_red "Test sshd config failed!"
        return 1 
    fi

    local conf_for_check=""
    if ! conf_for_check="$(sshd -T)"; then
        echo_red "Cannot get sshd config from sshd!"
        return 1 
    fi

    if ! grep -q "$setting" <<<"$conf_for_check"; then
        echo_red "Cannot found setting '$setting' in sshd config!"
        return 1 
    fi

    echo_green "SSHD config is valid! Restart..."

    if ! systemctl restart ssh.service; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_apply_setting() {
    local setting="${1}"
    local conf_file="${2}"

    if [ ! -f "$conf_file" ]; then
        echo "$setting" > "$conf_file" 
    fi

    if ! grep -q "$setting" "$conf_file"; then
        echo_yellow "Change to new sshd port setting $setting"
        echo "$setting" > "$conf_file"
    fi

    if ! chmod 600 "$conf_file"; then
        echo_yellow "Cannot change mode for config file $conf_file"
    else
        if ! chown "root:root" "$conf_file"; then
            echo_yellow "Cannot change owner to root for config file $conf_file"
        fi
    fi

    if ! sshd_verify_and_restart "$setting"; then
        echo_yellow "Remove config $conf_file file and restart..."
        if ! delete_file "$conf_file"; then
            echo_red "Cannot remove port file config $conf_file"
        fi

        if ! systemctl restart ssh.service; then
            echo_red "!!! SSHD was not restarted !!!"
        fi

        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_run() {
    if [[ "${DISABLE_PREPARE_SSHD-no}" == "true" ]]; then
        echo_yellow "prepare sshd!"
        return 0
    fi

    local port="${SSHD_PORT-}"
    if [ -z "$port" ]; then
        echo_red "SSHD port not passed"
        return 1
    fi

    if ! [[ $port =~ ^[0-9]+$ ]]; then
        echo_red "SSHD port is not number"
        return 1
    fi

    echo_green "Prepare sshd..."

    local base_cfgs_dir="/etc/ssh/sshd_config.d"

    echo_green "Prepare sshd. Disable systemd socket..."

    if ! systemctl enable --now ssh.service; then
        echo_red "Cannot enable ssh.service"
        return 1
    fi

    if ! systemctl stop ssh.socket; then
        echo_red "Cannot stop ssh.socket"
        return 1
    fi

    if ! systemctl disable --now ssh.socket; then
        echo_red "Cannot disabe ssh.socket"
        return 1
    fi

    echo_green "Prepare sshd. Apply new port..."

    local port_setting="Port $port"
    local port_file="${base_cfgs_dir}/99_z_port.conf"

    if ! sshd_apply_setting "$port_setting" "$port_file"; then
        echo_red "Cannot apply sshd port setting '$port_setting'"
        return 1
    fi

    echo_green "Prepare sshd. New port applyer!"
    echo_green "Please verify that ssh available on port $port"

    if ! ask_user "SSH available? Continue?"; then
        echo_red "Disallow continue"
        return 1
    fi

    echo_green "Prepare sshd. Disable root login..."

    local auth_present=""
    # shellcheck disable=SC2044
    for auth_file in $(find /home -name "authorized_keys"); do 
        if [ -s "$auth_file" ]; then
            echo_green "Found not empty authorized_keys $auth_file"
            auth_present="true"
        fi 
    done

    if [ -z "$auth_present" ]; then
        echo_red "Not found any non zero authorized_keys files. Cannot continue"
        return 1
    fi

    local root_setting="PermitRootLogin no"
    local root_file="${base_cfgs_dir}/99_z_disable_root.conf"

    if ! sshd_apply_setting "$root_setting" "$root_file"; then
        echo_red "Cannot disable root login '$root_setting'"
        return 1
    fi

    echo_green "Prepare sshd. Root login disabled!"
    echo_green "Please verify that ssh not avaiable with root"

    if ! ask_user "SSH not available with root? Continue?"; then
        echo_red "Disallow continue"
        return 1
    fi

    echo_green "Prepare sshd. Disable password auth..."

    local pass_setting="PasswordAuthentication no"
    local pass_file="${base_cfgs_dir}/99_z_disable_pass_auth.conf"

    if ! sshd_apply_setting "$pass_setting" "$pass_file"; then
        echo_red "Cannot apply sshd port setting '$pass_setting'"
        return 1
    fi

    echo_green "Prepare sshd. Password auth disabled!"
    echo_green "Please verify that ssh not avaiable with password auth"

    if ! ask_user "SSH passwor auth not available? Continue?"; then
        echo_red "Disallow continue"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_help() {
    echo -n "
    Change sshd port remove pass auth and root login
    Options:
      --sshd-port PORT
         Replace to new port.
         Can be provided with env SSHD_PORT
"
}

# shellcheck disable=SC2329
function phase_sshd_disable_env() {
    echo -n "DISABLE_PREPARE_SSHD"
}