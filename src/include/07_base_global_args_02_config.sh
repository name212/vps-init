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

    if [ -n "$config" ]; then
        echo_info "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a

        PROTECTED_PASSED_CONFIG_FILE="$config"
    fi
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
