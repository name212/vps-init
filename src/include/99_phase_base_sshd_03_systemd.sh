#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function sshd_fix_privilege_separation() {
    local not_ask="${1:-false}"

    local run_dir="/run/sshd"

    if ! mkdir -p "$run_dir"; then 
        echo_error "Cannot create $run_dir dir"
        return 1
    fi

    if ! chmod 0755 "$run_dir"; then
        echo_error "Cannot chmod $run_dir dir"
        return 1
    fi

    local tmpfiles_dir="/etc/tmpfiles.d"

    if ! mkdir -p "$tmpfiles_dir"; then 
        echo_error "Cannot create $tmpfiles_dir dir"
        return 1
    fi

    local tempfiles_conf_file="${tmpfiles_dir}/sshd.conf"

    local tempfiles_conf_content="d /run/sshd 0755 root root${CONST_NEW_LINE}"

    local ret_code_sync="0"
    if sync_file_content_with_diff_ret_code "$tempfiles_conf_content" "$tempfiles_conf_file" "sshd template files conf" "$not_ask"; then
        echo_debug "sshd template files conf '$tempfiles_conf_file' in sync"
        return 0
    else
        ret_code_sync="$?"
        if num_eq "$ret_code_sync" "255"; then
            echo_error "Cannot sync shd template files conf '$tempfiles_conf_file'"
            return 1
        fi
    fi

    echo_warn "Restart sshd after fix privilege separation..."

    # first arg nothing to move or remove
    if ! sshd_restart_with_approve "Fix privilege separation"; then
        echo_error "Cannot restart sshd after fix privilege separation"
        return 1
    fi

    echo_info "Verify sshd config after fix privilege separation..."
    
    if ! do_retry_func "5" "3" "Test sshd config after fix privilege separation" "sshd_check_config"; then
        echo_error "Test ssh config failed after fix privilege separation!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_disable_systemd_socket() {
    local not_ask="${1:-false}"

    if ! systemctl_is_enabled "$CONST_SSHD_PRIVATE_SYSTEMD_SERVICE"; then
        echo_info "Enable sshd service..."
        if ! systemctl_enable_service "$CONST_SSHD_PRIVATE_SYSTEMD_SERVICE"; then
            echo_error "Cannot enable $CONST_SSHD_PRIVATE_SYSTEMD_SERVICE"
            return 1
        fi

        echo_info "SSHD service enabled! Restart..."

        if ! sshd_restart; then
            return 1
        fi
    fi

    if ! disable_and_stop_services "ssh.socket"; then
        echo_error "Cannot stop systemd ssh socket"
        return 1
    fi

    echo_info "Create missing privilege separation directory..."
    if ! sshd_fix_privilege_separation "$not_ask"; then
        return 1 
    fi

    return 0
}