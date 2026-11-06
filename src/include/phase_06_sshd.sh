#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="06"

CONST_SSHD_PORT_ARG="--sshd-port"
CONST_SSHD_PORT_ENV="SSHD_PORT"

CONST_SSHD_LISTEN_ADDR_ARG="--sshd-listen-address"
CONST_SSHD_LISTEN_ADDR_ENV="SSHD_LISTEN_ADDRESS"

# shellcheck disable=SC2329
function phase_sshd_run() {
    local port=""
    local bind_address=""

    if ! port="$(extract_value_argument "$CONST_SSHD_PORT_ARG" "$CONST_SSHD_PORT_ENV" "validate_arg_port_optional" "$@")"; then
        echo_error "Incorrect sshd port"
        return 1
    fi

    if ! bind_address="$(extract_value_argument "$CONST_SSHD_LISTEN_ADDR_ARG" "$CONST_SSHD_LISTEN_ADDR_ENV" "validate_arg_ipv4_optional" "$@")"; then
        echo_error "Incorrect bind listen sshd address"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_info "Prepare sshd..."

    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    if [[ "$service_engine" == "$CONST_SYS_SERVICE_ENGINE_SYSTEMD" ]]; then
        if ! sshd_disable_systemd_socket; then
            return 1
        fi
    fi

    echo_debug "Prepare sshd. Apply new port..."

    if ! sshd_apply_port "$port" "$not_ask"; then
        return 1
    fi

    echo_debug "Prepare sshd. Apply bind address..."

    if ! sshd_add_bind_address "$bind_address" "$port" "$not_ask"; then
        return 1
    fi

    echo_info "Prepare sshd. Check that one of non-root user has authorized keys..."
    
    if ! sshd_has_authorized_keys_for_non_rot_users; then
        echo_error "Cannot continue"
        return 1
    fi

    echo_debug "Prepare sshd. Disable root login..."

    if ! sshd_apply_disable_root_login "$not_ask"; then
        return 1
    fi

    echo_debug "Prepare sshd. Disable password auth..."

    if ! sshd_apply_disable_password_login "$not_ask"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_help() {
    echo -n "
    Change sshd port remove pass auth and root login.
    
    Options:
      $CONST_SSHD_PORT_ARG PORT_NUM
         Replace to new port.
         Can be provided with env $CONST_SSHD_PORT_ENV
         Optional.

      $CONST_SSHD_LISTEN_ADDR_ARG ADDRESS
         Bind sshd to passed address if passed.
         Can be provided with env $CONST_SSHD_LISTEN_ADDR_ENV
         Optional.
"
}

# shellcheck disable=SC2329
function phase_sshd_disable_env() {
    echo -n "DISABLE_PREPARE_SSHD"
}