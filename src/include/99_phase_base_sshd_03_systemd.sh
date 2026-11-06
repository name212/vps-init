#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function sshd_fix_privilege_separation() {
    local run_dir="/run/sshd"

    if ! mkdir -p "$run_dir"; then 
        echo_error "Cannot create $run_dir dir"
        return 1
    fi

    if ! chmod 0755 "$run_dir"; then
        echo_error "Cannot chmod $run_dir dir"
        return 1
    fi

    local tmpfiles_dir="/etc/tmpfiles.d/"

    if ! mkdir -p "$tmpfiles_dir"; then 
        echo_error "Cannot create $tmpfiles_dir dir"
        return 1
    fi

    local tempfiles_conf_file="${tmpfiles_dir}/sshd.conf"

    echo "d /run/sshd 0755 root root" > "$tempfiles_conf_file"

    echo_info "Restart sshd after fix privilege separation..."

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
    echo_info "Enable sshd service..."
    if ! systemctl enable --now ssh.service; then
        echo_error "Cannot enable ssh.service"
        return 1
    fi

    echo_info "SSHD service enabled! Restart..."

    if ! sshd_restart; then
        echo_error "!!! SSHD was not restarted !!!"
        return 1
    fi

    if ! disable_and_stop_services "ssh.socket"; then
        echo_error "Cannot stop systemd ssh socket"
        return 1
    fi

    echo_info "Create missing privilege separation directory..."
    if ! sshd_fix_privilege_separation; then
        return 1 
    fi

    return 0
}