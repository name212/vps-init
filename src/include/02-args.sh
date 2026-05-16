#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_FLAG_SET="true"
export CONST_NO_VALIDATE="no_validate"
export CONST_IS_FLAG="true"
export CONST_NOT_FLAG="false"
export CONST_ARG_NOT_PASSED="false"
export CONST_ARG_PASSED="true"

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
        echo "Can be desabled with set env ${env_name}=true"
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
        echo_red "Internal error: '$validator' func not declared!"
        return 1
    fi

    local prepared
    if ! prepared="$($validator "$val" "$arg_passed")"; then
        echo_red "Incorrect: $prepared"
        return 1
    fi

    echo -n "$prepared"
    return 0
}

function arg_flag_is_set() {
    # shellcheck disable=SC2155
    local res="$(extract_argument "$@")"
    if [[ "$res" == "$CONST_FLAG_SET" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function parse_not_ask() {
    arg_flag_is_set "--not-ask" "NOT_ASK" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_not_empty_file() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo -n ""
        return 0
    fi

    if [ -z "$val" ]; then
        echo "Empty file path"
        return 1 
    fi

    local real=""

    if ! real="$(realpath "$val")"; then
        echo "cannot extract real path for $val"
        return 1
    fi

    if [ ! -f "$real" ]; then
        echo "$val is not file!"
        return 1
    fi

    if [ ! -s "$real" ]; then
        echo "$val is empty file!"
        return 1
    fi

    echo -n "$real"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_not_empty() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty arg val"
        return 1 
    fi

    echo -n "$val"
    return 0
}

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