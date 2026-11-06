#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function sshd_revert_after_apply() {
    local move_dict="${1:-}"
    shift

    local has_error="false"

    if ! str_empty "$move_dict"; then
        if ! is_dict_var "$move_dict"; then
            echo_error "Revert files dict '$move_dict' is not dict!"
            return 1
        fi

        local -n __sshd_revert_move="$move_dict"

        for src in "${!{__sshd_revert_move[@]}}"; do 
            local dest="${__sshd_revert_move[$src]}"
            if str_empty "$src" || str_empty "$dest"; then
                echo_warn "Source '$src' or dest '$dest' file is empty. Skip revert it"
                continue
            fi

            echo_warn "Revert (copy) old config from '$src' to '$dest'"
            if ! cp "$src" "$dest"; then
                has_error="true"
                echo_error "Cannot revert '$dest'"
            else
                if ! rm -f "$src"; then
                    echo_warn "Template file '$src' not removed for '$dest', but copied. Continue"
                fi
            fi
        done
    fi
    
    for rm_c in "$@"; do
        echo_warn "Remove config '$rm_c'"
        if ! rm -f "$rm_c"; then
            echo_error "Cannot remove config '$rm_c'"
            has_error="true"
        fi
    done

    if str_eq "$has_error"; then
        echo_error "^^Some configs cannot reverted. Skip restart sshd"
        return 1
    fi

    if ! sshd_check_config; then
        echo_error "sshd config not valid after revert. Skip restart sshd"
        return 1
    fi

    echo_warn "Restart sshd after revert..."

    if ! sshd_restart; then
        echo_error "Cannot restart sshd"
        return 1
    fi

    echo_green "sshd restarted after revert"
    return 0
}

# shellcheck disable=SC2329
function sshd_restart_with_approve() {
    local action_name="${1:-}"
    local revert_with_move_dict="${2:-}"
    shift
    shift

    local -a __sshd_empty_restart_args=()

    local -a __sshd_restart_revert_args=(
        "$revert_with_move_dict"
    )

    for rm_c_r in "$@"; do
        __sshd_restart_revert_args+=("$rm_c_r")
    done

    local -a __ssh_restart_args=(
        # wait
        "$DEFAULT_LOST_CONNECTION_WAIT_SEC"
        "$action_name"
        # not new address here
        ""
        # restart action
        "sshd_restart"
        # restart args
        "__sshd_empty_restart_args"
        # revert func
        "sshd_revert_after_apply"
        # revert args
        "__sshd_restart_revert_args"
    )

    do_action_with_with_wait_to_continue "${__ssh_restart_args[@]}"
    return $?
}

# shellcheck disable=SC2329
function sshd_apply_setting_with_approve() {
    local action_name="$1"
    local verify_message="$2"
    local setting="$3"
    local conf_file="$4"
    local not_ask="${5:-false}"
    local move_older="${6:-}"

    local -A __sshd_to_move=()

    if ! str_empty "$move_older"; then
        if ! is_dict_var "$move_older"; then
            echo_error "Backup files dict name '$move_older' is not dict for action '$action_name'"
            return 1
        fi

        local -n __ssd_move_older_dict="$move_older"
        for src_m in "${!__ssd_move_older_dict[@]}"; do
            __sshd_to_move["$src_m"]="${__ssd_move_older_dict[$src_m]}"
        done
    fi

    local old_conf_file=""

    local -a __sshd_revert_args=(
        "__sshd_to_move" # dict to reverts
    )

    if [ -f "$conf_file" ]; then
        echo_info "Conf file for setting '$setting' already present. Save to temp file"
        if ! old_conf_file="$(tmp_backup_file "$conf_file" "sshd")"; then
            echo_error "Cannot backup sshd conf file '$conf_file' for action '$action_name'"
            return 1
        fi

        echo_info "Temp file for '$conf_file' is '$old_conf_file' for action '$action_name'"
        __sshd_to_move["$old_conf_file"]="$conf_file"
    else
        __sshd_revert_args+=("$conf_file") # config file not present, will remove in revert
    fi

    local ret_code_sync_file="0"

    if sync_file_content_with_diff_ret_code "$setting" "$conf_file" "Apply sshd setting '$action_name'" "$not_ask"; then
        echo_info "Setting for action '$action_name' in file '$conf_file' in sync"
        for kk in "${!__sshd_to_move}"; do
            local rm_f="${__sshd_to_move[$kk]}"
            echo_info "Remove temp file '$rm_f' for config '$kk' for action '$action_name'"
            if ! rm -f "$rm_f"; then
                echo_warn "Temp file '$rm_f' for config '$kk' for action '$action_name' not removed!"
            fi 
        done
        return 0
    else
        ret_code_sync_file="$?"
        if num_eq "$ret_code_sync_file" "255"; then
            echo_error "Cannot sync config file '$conf_file' for action '$action_name'"
            if ! sshd_revert_after_apply "${__sshd_revert_args[@]}"; then
                echo_error "Cannot revert configs after fail sync for action '$action_name'!"
                return 1
            fi
        fi

        echo_info "sshd config '$conf_file' for action '$action_name' was changed. Try to apply:"
        echo_info "$setting"
    fi

    if ! set_only_root_perm_for_path "$conf_file"; then
        echo_error "Cannot set permission and change owner to root for config '$conf_file' for action '$action_name'"
        if ! sshd_revert_after_apply "${__sshd_revert_args[@]}"; then
            echo_error "Cannot revert configs after fail change permissions for action '$action_name'!"
            return 1
        fi
    fi

    echo_info "Check sshd config for action '$action_name'"

    if ! sshd_check_config; then
        echo_error "sshd config not valid for action '$action_name'. Settings":
        echo_error "$setting"
        if ! sshd_revert_after_apply "${__sshd_revert_args[@]}"; then
            echo_error "Cannot revert configs after check sshd config for action '$action_name'!"
            return 1
        fi
        return 1
    fi

    echo_warn "Try to restart sshd for action '$action_name'"
    if ! str_empty "$verify_message"; then
        echo_warn "Please check:"
        echo_warn "  $verify_message"
        echo_warn "before approve!"
    fi

    if ! sshd_restart_with_approve "$action_name" "${__sshd_revert_args[@]}"; then
        echo_error "Cannot apply setting for action '$action_name' with file '$conf_file'"
        return 1
    fi

    echo_info "Apply sshd setting '$action_name' done!"

    return 0
}

# shellcheck disable=SC2329
function sshd_apply_settings_with_check_not_own() {
    local action_name="$1"
    local verify_message="$2"
    local settings_dict_name="$3"
    local conf_file_name="$4"
    local not_ask="${5:-false}"

    if str_empty "$action_name"; then
        echo_error "Action name is empty for sshd_apply_settings_with_check_not_own"
        return 1
    fi

    if str_empty "$conf_file_name"; then
        echo_error "Conf file name is empty for action '$action_name'"
        return 1
    fi

    if ! is_dict_var "$settings_dict_name"; then
        echo_error "Settings dict name '$settings_dict_name' is not dict for '$action_name'"
        return 1
    fi

    if is_dict_has_len "$settings_dict_name" "0"; then
        echo_error "Settings dict '$settings_dict_name' is empty for '$action_name'"
        return 1
    fi

    local __sshd_settings_for_apply_dict="$settings_dict_name"
    local setting_to_set_str=""

    for sett_name_a in "${!__sshd_settings_for_apply_dict}"; do
        local cur_sett_str="${sett_name_a} ${__sshd_settings_for_apply_dict[$sett_name_a]}"
        setting_to_set_str="$(append_str_with_new_line "$setting_to_set_str" "$cur_sett_str")"
    done

    if ! setting_to_set_str="$(awk -F\; '{print $1|"sort -u"}' <<<"$setting_to_set_str")"; then
        echo_error "Cannot sort settings for action '$action_name'"
        return 1
    fi

    local -A __sshd_apply_remove_bkp=()

    if ! sshd_remove_settings_from_not_own_config "$settings_dict_name" "__sshd_apply_remove_bkp" "$not_ask"; then
        echo_error "Cannot remove settings from not own configs for action '$action_name'"
        return 1
    fi

    # shellcheck disable=SC2155
    local conf_file="$(sshd_get_conf_path "$conf_file_name")"

    if ! sshd_apply_setting_with_approve "$action_name" "$verify_message" "$setting_to_set_str" "$conf_file" "$not_ask" "__sshd_apply_remove_bkp"; then
        echo_error "Cannot apply settings for action name '$action_name'"
        echo_error "$setting_to_set_str"
        return 1
    fi

    return 0
}