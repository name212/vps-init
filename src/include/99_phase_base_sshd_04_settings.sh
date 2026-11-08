#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function sshd_apply_port() {
    local port="$1"
    local not_ask="${2-false}"

    if str_empty "$port"; then
        echo_warn "New port is not passed. Skip apply"
        echo_warn "If you need revert, please remove it manually"
        return 0
    fi

    if ! check_is_number_port "$port" > /dev/null; then
        echo_error "Invalid sshd port number '$port'"
        return 1
    fi

    local -A __sshd_port_dict=()
    __sshd_port_dict["Port"]="$port"

    if ! sshd_apply_settings_with_check_not_own "Apply sshd port" "ssh USER@HOST -p $port" "__sshd_port_dict" "port" "$not_ask"; then
        echo_error "Cannot apply sshd port '$port' setting"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_add_bind_address() {
    local listen_address="${1:-}"
    local port="${2:-}"
    local not_ask="${3-no}"

    if str_empty "$listen_address"; then
        return 0    
    fi

    # shellcheck disable=SC2155
    local listen_conf_path="$(sshd_get_conf_path "listen")"

    local listen_setting=""

    if [[ "$listen_address" == "0.0.0.0" || "$listen_address" == "::" ]]; then
        listen_setting="ListenAddress 0.0.0.0${CONST_NEW_LINE}ListenAddress ::${CONST_NEW_LINE}"
    elif [[ -f "$listen_conf_path" ]]; then
        if ! listen_setting="$(cat "$listen_conf_path")"; then
            echo_error "Cannot cat '$listen_conf_path'"
            return 1
        fi

        if grep -q "ListenAddress 0.0.0.0" <<<"$listen_setting"; then
            listen_setting=""
        fi 
        
        if grep -q "$listen_address" <<<"$listen_setting"; then
            echo_info "$listen_address' already exists in '$listen_conf_path'. Skip:"
            echo_info "$listen_setting"
            return 0
        else
            listen_setting="${listen_setting}${CONST_NEW_LINE}ListenAddress ${listen_address}${CONST_NEW_LINE}"
        fi
    else
        listen_setting="ListenAddress ${listen_address}${CONST_NEW_LINE}"
    fi

    if [ -z "$listen_setting" ]; then
        echo_error "Listen settings is empty"
        return 1
    fi

    local listen_setting_to_set=""
    if ! listen_setting_to_set="$(awk -F\; '{print $1|"sort -u"}' <<<"$listen_setting")"; then
        echo_error "Cannot sort listen settings"
        return 1
    fi

    if [ -z "$listen_setting_to_set" ]; then
        echo_error "Listen settings is empty after sort"
        return 1
    fi

    if ! sshd_apply_setting_with_approve "Listen address" "SSH available?" "$listen_setting_to_set" "$listen_conf_path" "$not_ask"; then
        echo_error "Cannot apply sshd listing setting:${CONST_NEW_LINE}${listen_setting_to_set}"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_apply_disable_root_login() {
    local not_ask="${1-false}"
   
    local -A __sshd_disable_root_dict=()
    __sshd_disable_root_dict["PermitRootLogin"]="no"

    if ! sshd_apply_settings_with_check_not_own "Disable login via root user" "ssh not available with root" "__sshd_disable_root_dict" "disable_root" "$not_ask"; then
        echo_error "Cannot disable login via root user"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_apply_disable_password_login() {
    local not_ask="${1-false}"

    local -A __sshd_disable_password_dict=()
    __sshd_disable_password_dict["PasswordAuthentication"]="no"

    local verify_msg="ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no YOUR_USER@HOST"

    if ! sshd_apply_settings_with_check_not_own "Disable login with password" "$verify_msg" "__sshd_disable_password_dict" "disable_pass_auth" "$not_ask"; then
        echo_error "Cannot disable login with password"
        return 1
    fi

    return 0
}