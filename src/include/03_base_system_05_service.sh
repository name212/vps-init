#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_SYS_SERVICE_ENGINE_SYSTEMD="systemctl"
# shellcheck disable=SC2034
CONST_SYS_SERVICE_ENGINE_INITD="service"

declare -A _SYS_SERVICE_ENGINES_MAP=()
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="true"
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_INITD"]="true"

if [ -z "${SYS_SERVICE_ENGINE:-}" ]; then
    export SYS_SERVICE_ENGINE="$CONST_SYS_SERVICE_ENGINE_SYSTEMD"
fi

# shellcheck disable=SC2034
CONST_SERVICE_SKIP_RESTART_AFTER_REVERT_RET_CODE="250"

# shellcheck disable=SC2329
function get_sys_service_engine() {
    if [[ -v _SYS_SERVICE_ENGINES_MAP["$SYS_SERVICE_ENGINE"] ]]; then
        echo -n "$SYS_SERVICE_ENGINE"
        return 0
    fi

    echo_error "SYS_SERVICE_ENGINE '${SYS_SERVICE_ENGINE}' incorrect"
    return 1
}

# shellcheck disable=SC2329
function _get_sys_service_engine_fun() {
    local fun="$1"

    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    local full_fun="${service_engine}_$fun"

    if ! is_function_declared "$full_fun"; then
        echo_error "Internal error: '$full_fun' func not declared!"
        return 1
    fi 

    echo -n "$full_fun"
    return 0
}

# shellcheck disable=SC2329
function systemctl_disable_all() {
    local srv="$1"

    if [ -z "$srv" ]; then
        echo_error "Service to disable not passed"
        return 1
    fi

    if ! systemctl is-active "$srv"; then
        return 0
    fi

    echo_info "systemd service $srv is active. Disable..."

    if ! systemctl disable --now "$srv"; then
        echo_error "Cannot disable $srv"
        return 1
    fi

    if ! systemctl stop "$srv"; then
        echo_error "Cannot stop $srv"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function systemctl_enable_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 1
    fi


    if ! systemctl enable --now "$srv"; then
        echo_error "Service '$srv' cannot enable"
        return 1
    fi
}

# shellcheck disable=SC2329
function systemctl_restart_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 255
    fi


    if ! systemctl restart "$srv"; then
        echo_error "Service '$srv' cannot restarted"
        return 1
    fi
}

# shellcheck disable=SC2329
function service_disable_all() {
    local srv="$1"

    if [ -z "$srv" ]; then
        echo_error "Service to disable not passed"
        return 1
    fi

    if ! service "$srv" disable; then
        echo_error "Cannot disable $srv"
        return 1
    fi

    if ! service "$srv" stop; then
        echo_error "Cannot stop $srv"
        return 1
    fi
    return 0
}

# shellcheck disable=SC2329
function service_enable_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 1
    fi


    if ! service "$srv" enable; then
        echo_error "Service '$srv' cannot enable"
        return 1
    fi

    if ! service "$srv" restart; then
        echo_error "Service '$srv' cannot restarted"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function service_restart_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 255
    fi


    if ! service "$srv" restart; then
        echo_error "Service '$srv' cannot restarted"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function disable_and_stop_services() {
    local disable_fun=""
    if ! disable_fun="$(_get_sys_service_engine_fun "disable_all")"; then
        echo_error "Cannot get run function for disable and sto services"
    fi

    local -a not_disabled=()

    for srv in "$@"; do
        if ! "$disable_fun" "$srv"; then
            not_disabled+=("$srv")
        fi
    done

    if [[ "${#not_disabled[@]}" == 0 ]]; then
        return 0
    fi

    echo_error "Next services not disabled: ${not_disabled[*]}"
    return 1
}


# shellcheck disable=SC2329
function restart_service_with_revert() {
    local service_name="${1}"

    if [ -z "$service_name" ]; then
        echo_error "Service name for restart with revert is not passed"
        return 255
    fi

    shift

    local revert_func="${1:-}"
    local -a revert_func_args=()


    if [ -n "$revert_func" ]; then
        if is_function_declared "$revert_func"; then
            echo_error "Function to revert restart service '$revert_func' is not declared."
            return 255
        fi

        shift

        for r_arg in "$@"; do
            revert_func_args+=("$r_arg")
        done
    fi

    local restart_fun=""
    if ! restart_fun="$(_get_sys_service_engine_fun "restart_service")"; then
        echo_error "Cannot get run function for restart service '$service_name'"
        return 255
    fi
    

    echo_warn "Service '$service_name' will restart"
    if "$restart_fun" "$service_name"; then
       echo_green "Service '$service_name' was restarted"
       return 0
    fi

    echo_error "Service '$service_name' restart failed"
    if [ -z "$revert_func" ]; then
        return 1
    fi

    echo_warn "Run revert service '$service_name' function '$revert_func ${revert_func_args[*]}'"

    local ret_code_revert="0"
    if "$revert_func" "${revert_func_args[@]}"; then
        echo_warn "Restart service '$service_name' after successful revert"
        if ! "$restart_fun" "$service_name"; then
            echo_error "Service '$service_name' restart failed after revert"
        fi
    else
        ret_code_revert="$?"
        if num_eq "$ret_code_revert" "$CONST_SERVICE_SKIP_RESTART_AFTER_REVERT_RET_CODE"; then
            echo_info "Revert service '$service_name' successful but service should not restart"
            return 1
        fi

        echo_error "Revert service '$service_name' function failed"
    fi

    return 1
}
