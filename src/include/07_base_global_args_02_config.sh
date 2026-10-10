#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_CONFIG_FILE_ARG="--config"
# shellcheck disable=SC2034
export CONST_CONFIG_FILE_ENV="CONFIG_PATH"

# shellcheck disable=SC2034
export PROTECTED_PASSED_CONFIG_FILE=""

# shellcheck disable=SC2329
function parse_and_apply_config_file() {
    if is_help_flag_set "$@"; then
        return 0
    fi

    local config=""

    if ! config="$(extract_value_argument "$CONST_CONFIG_FILE_ARG" "$CONST_CONFIG_FILE_ENV" "validate_arg_not_empty_file_optional" "$@")"; then
        echo_error "Passed config is incorrect: $config"
        return 1
    fi

    if [ -z "$config" ]; then
        return 0
    fi

    echo_info "Load config $config"
    
    local -A system_envs_before=()
    if ! get_envs_dict "system_envs_before"; then
        echo_warn "Cannot get current envs before source config '$config'"
    fi
    
    if ! load_envs_file "$config"; then
        echo_error "Cannot load config file '$config'"
        return 1
    fi

    PROTECTED_PASSED_CONFIG_FILE="$config"

    local -A system_envs_after=()
    if ! get_envs_dict "system_envs_after"; then
        echo_warn "Cannot get current envs after source config '$config'"
    fi

    for env_name in "${!system_envs_after[@]}"; do
        local after_val="${system_envs_after[$env_name]}"
        if ! is_dict_has_key "system_envs_before" "$env_name"; then
            continue
        fi

        local before_val="${system_envs_before[$env_name]}"

        if [[ "$before_val" == "$after_val" ]]; then
            continue
        fi

        echo_warn "Config env '$env_name' found in system env passed before load config and changed. Restore to before load config val"
        export "$env_name"="$before_val"
    done
}

# shellcheck disable=SC2329
function check_config_file_set_and_get() {
    if [ -z "${PROTECTED_PASSED_CONFIG_FILE:-}" ]; then
        return 1
    fi

    echo -n "$PROTECTED_PASSED_CONFIG_FILE"
    return 0
}

# shellcheck disable=SC2329
function config_file_help() {
    echo -n "
    ${CONST_CONFIG_FILE_ARG}
      Path to config with envs to settings.
      Should be .env format
      Env $CONST_CONFIG_FILE_ENV" sor set.
}
