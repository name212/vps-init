#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function trap_all() {
    local fn="${1:-}"
    
    if [ -z "$fn" ]; then
        return 0
    fi

    if ! is_function_declared "$fn"; then
        echo_error "Function '$fn' is not declared for trap"
    fi

    # shellcheck disable=SC2086
    trap $fn EXIT
    # shellcheck disable=SC2086
    trap $fn SIGINT
    # shellcheck disable=SC2086
    trap $fn SIGTERM

    echo_debug "Set trap function '$fn' for EXIT SIGINT SIGTERM"
}

# shellcheck disable=SC2329
function get_env_value_or_default() {
    local var_name="$1"
    local default_val="${2-}"

    if ! [[ -v "$var_name" ]]; then
        echo -n "$default_val"
        return 0
    fi

    echo -n "${!var_name}"
    return 0
}

# shellcheck disable=SC2329
function get_envs_dict() {
    local var_name="$1"
    
    local env_out=""
    if ! env_out="$(env)"; then
        echo_error "Cannot get current envs"
        return 1
    fi

    local -a envs_strings=()

    if ! split_by_new_line "envs_strings" "$env_out"; then
        echo_error "Cannot split env out by new line"
        return 1
    fi

    local -n get_envs_map_target="$var_name"

    local indx="-1"
    for one_env_str in "${envs_strings[@]}"; do
        ((indx++))

        if [ -z "$one_env_str" ]; then
            continue
        fi

        local -a key_val=()
        if ! split_by_eq "key_val" "$one_env_str"; then
            echo_error "Cannot split one env str $indx by '='"
            return 1
        fi

        if is_array_has_len "key_val" "1"; then
            echo_warn "One env str $indx has not val. Skip"
            continue
        fi

        local name="${key_val[0]}"
        local val=""

        local kv_indx="-1"
        for vv in "${key_val[@]}"; do
            ((kv_indx++))
            if  num_eq "$kv_indx" "0"; then
                continue
            fi
            val="$(append_str_with_separator "=" "$val" "$vv")"
        done

        # shellcheck disable=SC2034
        get_envs_map_target["$name"]="$val"
    done

    return 0
}
