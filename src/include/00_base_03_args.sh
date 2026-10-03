#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_FLAG_SET="true"
# shellcheck disable=SC2034
export CONST_IS_FLAG="__is_flag__"
# shellcheck disable=SC2034
export CONST_NOT_FLAG="__not_is_flag__"
# shellcheck disable=SC2034
export CONST_ARG_NOT_PASSED="__not_passed_arg__"
# shellcheck disable=SC2034
export CONST_ARG_PASSED="__arg_passed"
# shellcheck disable=SC2034
export CONST_NOT_ASK_ARG="--not-ask"
export CONST_NOT_ASK_ENV="NOT_ASK"

declare -a CONST_HELP_AGS=("-h" "--help")

# shellcheck disable=SC2329
function __no_validate() {
    local val="$1"
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function disable_env() {
    local phase="$1"

    local env_name=""

    local env_fun="phase_${phase}_disable_env"
    if declare -F "$env_fun" > /dev/null; then
        env_name="$("$env_fun")"
    fi

    echo -n "$env_name"
}

function phase_is_not_disabled() {
    local phase="$1"

     # shellcheck disable=SC2155
    local env_name="$(disable_env "$phase")"

    if [ -z "$env_name" ]; then
        return 0
    fi

    if [ -v "$env_name" ]; then
        if [[ "${!env_name:-}" == "$CONST_FLAG_SET" ]]; then
            return 1
        fi
    fi

    return 0
}

function disable_help() {
    local phase="$1"

    # shellcheck disable=SC2155
    local env_name="$(disable_env "$phase")"

    if [ -n "$env_name" ]; then
        echo "Can be disabled with set env ${env_name}=true"
        return 0
    fi

    echo "This phase is required and not be disabled!"
}

function extract_argument() {
    local arg_name="$1"
    local env_name="$2"
    local is_flag="$3"
    local validator="$4"

    shift
    shift
    shift
    shift

    local val=""

    local arg_passed="$CONST_ARG_NOT_PASSED"

    local extract_and_break=""
    for arg in "$@"; do
        if [[ "$extract_and_break" == "true" ]]; then
            val="$arg"
            break
        fi

        if [[ "$arg" == "$arg_name" ]]; then
            arg_passed="$CONST_ARG_PASSED"
            if [[ "$is_flag" == "$CONST_IS_FLAG" ]]; then
                val="$CONST_FLAG_SET"
            else
                extract_and_break="true"
            fi
        fi
    done

    if [ -n "$env_name" ]; then
        if [ -v "$env_name" ]; then
            val="${!env_name:-}"
            arg_passed="$CONST_ARG_PASSED"
        fi
    fi

    if [[ "$is_flag" == "$CONST_IS_FLAG" ]]; then
        echo -n "$val"
        return 0
    fi

    if [[ "$validator" == "" || "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$val"
        return 0
    fi

    if ! declare -F "$validator" > /dev/null; then
        echo_error "Internal error: '$validator' func not declared!"
        return 1
    fi

    local prepared
    if ! prepared="$($validator "$val" "$arg_passed")"; then
        echo_error "Incorrect: $prepared"
        return 1
    fi

    echo -n "$prepared"
    return 0
}

function extract_value_argument() { 
    local arg_name="$1"
    local env_name="$2"
    local validator="$3"

    shift
    shift
    shift

    local val=""
    if ! val="$(extract_argument "$arg_name" "$env_name" "$CONST_NOT_FLAG" "$validator" "$@")"; then
        echo -n ""
        return 1
    fi

    echo -n "$val"
    return 0
}

function extract_value_argument_no_validate() { 
    local arg_name="$1"
    local env_name="$2"

    shift
    shift

    local val=""
    if ! val="$(extract_argument "$arg_name" "$env_name" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo -n ""
        return 1
    fi

    echo -n "$val"
    return 0
}

function arg_flag_is_set() {
    local arg_name="$1"
    local env_name="${2}"

    shift
    shift

    # shellcheck disable=SC2155
    local res="$(extract_argument "$arg_name" "$env_name" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"
    if [[ "$res" == "$CONST_FLAG_SET" ]]; then
        return 0
    fi

    return 1
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
function parse_not_ask() {
    if arg_flag_is_set "$CONST_NOT_ASK_ARG" "$CONST_NOT_ASK_ENV" "$@"; then
        echo -n "$CONST_NOT_ASK_VAL"
        return 0
    fi

    echo "$CONST_ASK_VAL"
    return 0
}

# shellcheck disable=SC2329
function not_ask_help() {
    echo "
    ${CONST_NOT_ASK_ARG}
      If passed will not ask user about actions.
      Env ${CONST_NOT_ASK_ENV}=true for set.
    "
}

# shellcheck disable=SC2329
function is_help_flag_set() {
    for ha in "${CONST_HELP_AGS[@]}"; do 
        if arg_flag_is_set "$ha" "" "$@"; then
            return 0
        fi
    done

    return 1
}

# shellcheck disable=SC2329
function echo_help_args_help() {
    local args_list=""

    for hah in "${CONST_HELP_AGS[@]}"; do
        if [ -z "$args_list" ]; then
            args_list="$hah"
            continue
        fi

        args_list="${args_list}|${hah}"
    done 

    echo "
    ${args_list}
      Show this help message.
    "
}

# shellcheck disable=SC2329
function parse_and_apply_log_settings() {
    if arg_flag_is_set "$CONST_LOG_ARG_ENABLE_DEBUG" "$CONST_LOG_ENV_ENABLE_DEBUG" "$@"; then
        __enable_debug_log "true"
    fi

    local log_file=""
    if ! log_file="$(extract_value_argument_no_validate "$CONST_LOG_ARG_FILE" "$CONST_LOG_ENV_FILE" "$@")"; then
        echo_error "Cannot extract log file argument"
        return 1
    fi

    if [ -n "$log_file" ]; then
        if arg_flag_is_set "$CONST_LOG_ARG_UNIX_SECONDS" "$CONST_LOG_ENV_UNIX_SECONDS" "$@"; then
            local log_file_suf=""
            if ! log_file_suf="$(date +%s)"; then
                echo_error "Cannot get suffix for log file"
                return 1
            fi
            log_file="${log_file}.${log_file_suf}"
        fi

        if ! __set_log_file "$log_file"; then
            echo_error "Cannot set log file '$log_file'"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function log_settings_help() {
    echo "
    Log settings:
    $CONST_LOG_ARG_ENABLE_DEBUG
      If passed will output debug log information to terminal.
      Env ${CONST_LOG_ENV_ENABLE_DEBUG}=true for set.

    $CONST_LOG_ARG_FILE 'PATH'
      If set, all log include debug will write to file in format:
      [\$date] || [\$level]: \$msg
      Env $CONST_LOG_ENV_FILE

    $CONST_LOG_ARG_UNIX_SECONDS
      If set and pass log file path, will add unix time seconds
      as suffix of file path like (log file is /tmp/init-log.log):
        /tmp/init-log.log.1790520136
      Env ${CONST_LOG_ENV_UNIX_SECONDS}=true for set.
    "
 }
