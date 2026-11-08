#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_BASE_SSHD_CONFIG="/etc/ssh/sshd_config.d"
# shellcheck disable=SC2034
CONST_SSHD_FILE_CONF_PREFIX="99_z_"

# shellcheck disable=SC2034
CONST_SSHD_PRIVATE_SYSTEMD_SERVICE="ssh.service"

# shellcheck disable=SC2034
declare -A _SSH_SERVICE_NAME=()
# shellcheck disable=SC2034
_SSH_SERVICE_NAME["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="$CONST_SSHD_PRIVATE_SYSTEMD_SERVICE"
# shellcheck disable=SC2034
_SSH_SERVICE_NAME["$CONST_SYS_SERVICE_ENGINE_INITD"]="sshd"

# shellcheck disable=SC2329
function sshd_get_conf_path() {
    local name="$1"

    echo -n "${CONST_BASE_SSHD_CONFIG}/${CONST_SSHD_FILE_CONF_PREFIX}${name}.conf" 
}

# shellcheck disable=SC2329
function sshd_full_path() {
    local full_p=""
    if ! full_p="$(which sshd)"; then
        echo_error "Cannot which sshd"
        return 1
    fi

    if [ -z "$full_p" ]; then
        echo_error "which sshd is empty"
        return 1
    fi

    echo -n "$full_p"
    return 0
}

# shellcheck disable=SC2329
function sshd_check_config() {
    local settings="${1:-}"

    local sshd_bin=""
    if ! sshd_bin="$(sshd_full_path)"; then
        echo_error "Cannot get full path of sshd"
        return 1
    fi

    if ! "$sshd_bin" -t; then
        echo_error "Test sshd config failed!"
        return 1 
    fi

    if str_empty "$settings"; then
        echo_info "SSHD config is valid!"
        return 0
    fi

    local -a __sshd_settings_for_check=()
    if ! split_by_new_line "__sshd_settings_for_check" "$settings" "trim_spaces"; then
        echo_error "Cannot verify that configuration is present in sshd config. Cannot split configuration for check"
        echo_error "$settings"
        return 1
    fi

    local conf_for_check=""
    if ! conf_for_check="$("$sshd_bin" -T)"; then
        echo_error "Cannot get sshd config from sshd!"
        return 1 
    fi

    local failed="false"

    for st_str in "${__sshd_settings_for_check[@]}"; do
        if str_empty "$st_str"; then
            continue
        fi

        st_str="$(str_lower "$st_str")"

        if ! grep -qi "$st_str" <<<"$conf_for_check"; then
            echo_error "Cannot found setting '$st_str' in sshd config!"
            failed="true"
        fi
    done


    if str_eq "$failed" "true"; then
        echo_error "^^Not found setting in sshd!"
        return 1
    fi

    echo_info "SSHD config is valid!"

    return 0
}

# shellcheck disable=SC2329
function sshd_restart() {
    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    local svc_name=""
    if [[ -v _SSH_SERVICE_NAME["$service_engine"] ]]; then
        svc_name="${_SSH_SERVICE_NAME["$service_engine"]}"
    else
        echo_error "Restart sshd service name not found for service engine '$service_engine'"
        return 1
    fi

    # no revert
    if ! restart_service_with_revert "$svc_name"; then
        echo_error "!!! SSHD was not restarted !!!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_remove_settings_from_not_own_config() {
    local settings_dict_name="$1"
    local dest_sett_file_dict="$2"
    local not_ask="${3:-false}"

    if ! is_dict_var "$settings_dict_name"; then
        echo_error "Setting dict name '$settings_dict_name' is not dict for sshd_remove_setting_from_not_own_config"
        return 1
    fi

    if ! is_dict_var "$dest_sett_file_dict"; then
        echo_error "Destination backup files dict '$dest_sett_file_dict' is not dict for sshd_remove_setting_from_not_own_config"
        return 1
    fi

    local failed="false"

    local -n __sshd_settings_dict_to_remove="$settings_dict_name"

    local -A sett_present_in=()
    # shellcheck disable=SC2044
    for conf_path in $(find "$CONST_BASE_SSHD_CONFIG" -name "*.conf"); do 
        if [ ! -s "$conf_path" ]; then
            continue
        fi
        
        local conf_file=""
        if ! conf_file="$(basename "$conf_path")"; then
            echo_error "Cannot get base name for ssd conf file '$conf_path'"
            return 1
        fi

        if [[ "$conf_file" == "$CONST_SSHD_FILE_CONF_PREFIX"* ]]; then
            echo_debug "Found own ssh config file '$conf_file'. Skip"
            continue
        fi

        local -A setts_to_remove=()

        for sett_name in "${!__sshd_settings_dict_to_remove[@]}"; do
            local grep_out=""
            if grep_out="$(grep -iP "^$sett_name" "$conf_path")"; then
                setts_to_remove["$sett_name"]="$grep_out"
            fi
        done

        if is_dict_has_len "setts_to_remove" "0"; then
            echo_debug "Not found any passed settings in config file '$conf_path'. Skip"
            continue
        fi

        echo_warn "Found setting next settings in non-own config file '$conf_path':"
        for sett_name_o in "${!setts_to_remove[@]}"; do
            echo "${setts_to_remove[$sett_name_o]}"
        done

        if ! ask_user "Backup file '$conf_file' and remove settings" "$not_ask"; then
            echo_error "Disallow remove sshd settings from '$conf_path'"
            failed="true"
            continue
        fi

        local bkp_file=""
        if ! bkp_file="$(tmp_backup_file "$conf_path" "sshd")"; then
            echo_error "Cannot backup sshd conf file '$conf_path'"
            failed="true"
            continue
        fi

        sett_present_in["$bkp_file"]="$conf_path"

        for sett_name_r in "${!setts_to_remove[@]}"; do
            if ! sed -i "/^$sett_name_r/Id" "$conf_path"; then
                echo_error "Cannot remove setting '$sett_name_r' from '$conf_path'"
                failed="true"
                continue
            fi
        done
    done

    if str_eq "$failed" "true"; then
        echo_error "Fail remove sshd setting '$sett_name'. Revert files"
        for src in "${!sett_present_in[@]}"; do
            echo_warn "Revert '$dest' from '$src'"
            local dest="${sett_present_in[$src]}"
            if ! mv "$src" "$dest"; then
                echo_error "Cannot revert '$dest' from '$src'"
            fi
        done

        return 1
    fi

    local -n __sshd_settings_bkps="$dest_sett_file_dict"

    for src_f in "${!sett_present_in[@]}"; do
        __sshd_settings_bkps["$src_f"]="${sett_present_in[$src_f]}"
    done

    return 0
}

# shellcheck disable=SC2329
function sshd_has_authorized_keys_for_non_rot_users() { 
    local auth_present=""
    # shellcheck disable=SC2044
    for auth_file in $(find /home -name "authorized_keys"); do 
        if [ -s "$auth_file" ]; then
            echo_info "Found not empty authorized_keys $auth_file"
            auth_present="true"
        fi 
    done

    if ! str_eq "$auth_present" "true"; then
        echo_error "Not found any non zero authorized_keys files"
        return 1
    fi

    return 0
}
