#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_SYS_SERVICE_ENGINE_SYSTEMD="systemctl"
export CONST_SYS_SERVICE_ENGINE_INITD="service"

declare -A _SYS_SERVICE_ENGINES_MAP=()
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="true"
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_INITD"]="true"

if [ -z "${SYS_SERVICE_ENGINE:-}" ]; then
    export SYS_SERVICE_ENGINE="$CONST_SYS_SERVICE_ENGINE_SYSTEMD"
fi

# shellcheck disable=SC2329
function get_sys_service_engine() {
    if [[ -v _SYS_SERVICE_ENGINES_MAP["$SYS_SERVICE_ENGINE"] ]]; then
        echo -n "$SYS_SERVICE_ENGINE"
        return 0
    fi

    echo_red "SYS_SERVICE_ENGINE '${SYS_SERVICE_ENGINE}' incorrect"
    return 1
}

# shellcheck disable=SC2329
function systemd_disable_all() {
    local srv="$1"

    if [ -z "$srv" ]; then
        echo_error "Service to disable not passed"
        return 1
    fi

    if ! systemctl is-active "$srv"; then
        return 0
    fi

    echo_green "systemd service $srv is active. Disable..."

    if ! systemctl disable --now "$srv"; then
        echo_red "Cannot disable $srv"
        return 1
    fi

    if ! systemctl stop "$srv"; then
        echo_red "Cannot stop $srv"
        return 1
    fi

    return 0
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
function disable_and_stop_services() {
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    disable_fun="${service_engine}_disable_all"

    if ! declare -F "$disable_fun" > /dev/null; then
        echo_red "Internal error: '$disable_fun' func not declared!"
        return 1
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
function systemd_enable_service() {
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