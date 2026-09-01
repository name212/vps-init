#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="05"

declare -A _SSH_RESTART_FUNC=()
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="sshd_systemd_restart"
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_INITD"]="sshd_initd_restart"

function sshd_systemd_restart() {
    if ! systemctl restart ssh.service; then
        return 1
    fi

    return 0
}

function sshd_initd_restart() {
    if ! service sshd restart; then
        return 1
    fi

    return 0
}

function sshd_restart() {
    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_red "Cannot resolve system service engine"
        return 1
    fi

    local restart_fun=""
    if [[ -v _SSH_RESTART_FUNC["$service_engine"] ]]; then
        restart_fun="${_SSH_RESTART_FUNC["$service_engine"]}"
    else
        echo_red "Restart sshd func not found for service engine '$service_engine'"
        return 1
    fi

    if ! declare -F "$restart_fun" > /dev/null; then
        echo_red "Internal error: '$restart_fun' func not declared!"
        return 1
    fi

    if ! "$restart_fun"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_fix_privilegies_separation() {
    local run_dir="/run/sshd"

    if ! mkdir -p "$run_dir"; then 
        echo_red "Cannot create $run_dir dir"
        return 1
    fi

    if ! chmod 0755 "$run_dir"; then
        echo_red "Cannot chmod $run_dir dir"
        return 1
    fi

    local tmpfiles_dir="/etc/tmpfiles.d/"

    if ! mkdir -p "$tmpfiles_dir"; then 
        echo_red "Cannot create $tmpfiles_dir dir"
        return 1
    fi

    echo "d /run/sshd 0755 root root" > "${tmpfiles_dir}/sshd.conf"

    echo_green "Restart sshd after fix privilegies separation..."
    if ! sshd_restart; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_green "Verify sshd config after fix privilegies separation..."
    if ! sshd -t; then
        echo_yellow "Test sshd config failed after fix privilegies separation. Sleep 5 seconds before next attempt"
        sleep 5
        
        if ! sshd -t; then
            echo_red "Test sshd config after fix privilegies separation after second attempt!"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_disable_systemd_socket() {
    echo_green "Enable sshd service..."
    if ! systemctl enable --now ssh.service; then
        echo_red "Cannot enable ssh.service"
        return 1
    fi

    echo_green "SSHD service enabled! Restart..."

    if ! sshd_restart; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_green "Stop sshd systemd socket.."
    if ! systemctl stop ssh.socket; then
        echo_red "Cannot stop ssh.socket"
        return 1
    fi

    echo_green "Disable sshd systemd socket..."
    if ! systemctl disable --now ssh.socket; then
        echo_red "Cannot disabe ssh.socket"
        return 1
    fi

    echo_green "Create missing privilege separation directory..."
    if ! sshd_fix_privilegies_separation; then
        return 1 
    fi

    return 0
}

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

    if ! sshd_restart; then
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
        echo_yellow "Change to new sshd port setting to '$setting'"
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

        if ! sshd_restart; then
            echo_red "!!! SSHD was not restarted !!!"
        fi

        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_run() {
    local port=""
    local bind_address=""

    if ! port="$(extract_argument "--sshd-port" "SSHD_PORT" "$CONST_NOT_FLAG" "validate_arg_number" "$@")"; then
        echo_red "Incorrect sshd port"
        return 1
    fi

    if ! bind_address="$(extract_argument "--sshd-bind-address" "SSHD_BIND_ADDRESS" "$CONST_NOT_FLAG" "validate_arg_ipv4_optional" "$@")"; then
        echo_red "Incorrect bind sshd address"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Prepare sshd..."

    local base_cfgs_dir="/etc/ssh/sshd_config.d"

    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_red "Cannot resolve system service engine"
        return 1
    fi

    if [[ "$service_engine" == "$CONST_SYS_SERVICE_ENGINE_SYSTEMD" ]]; then
        if ! sshd_disable_systemd_socket; then
            return 1
        fi
    fi

    echo_green "Prepare sshd. Apply new port..."

    local port_setting="Port $port"
    local port_file="${base_cfgs_dir}/99_z_port.conf"

    if ! sshd_apply_setting "$port_setting" "$port_file"; then
        echo_red "Cannot apply sshd port setting '$port_setting'"
        return 1
    fi

    echo_green "Prepare sshd. New port apply!"
    echo_green "Please verify that ssh available on port $port"

    if ! ask_user "SSH available? Continue?" "$not_ask"; then
        echo_red "Disallow continue"
        return 1
    fi

    if [ -n "$bind_address" ]; then
        echo_green "Prepare sshd. Set bind address..."

        local bind_setting="ListenAddress $bind_address"
        local bind_file="${base_cfgs_dir}/99_z_bind.conf"

        if ! sshd_apply_setting "$bind_setting" "$bind_file"; then
            echo_red "Cannot apply sshd port setting '$bind_setting'"
            return 1
        fi

        echo_green "Prepare sshd. Bind address apply!"
        echo_green "Please verify that ssh available on port $port"

        if ! ask_user "SSH available? Continue?" "$not_ask"; then
            echo_red "Disallow continue"
            return 1
        fi
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
    echo_green "Please verify that ssh not available with root"

    if ! ask_user "SSH not available with root? Continue?" "$not_ask"; then
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
    echo_green "Please verify that ssh not available with password auth"
    echo_green "Can be verify with command:" 
    echo_green "ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no YOUR_USER@HOST"

    if ! ask_user "SSH password auth not available? Continue?" "$not_ask"; then
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
      --sshd-bind-address ADDRESS
         Bind sshd to passed address if passed.
         Can be provided with env SSHD_BIND_ADDRESS
         Optional.
"
}

# shellcheck disable=SC2329
function phase_sshd_disable_env() {
    echo -n "DISABLE_PREPARE_SSHD"
}