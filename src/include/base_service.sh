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