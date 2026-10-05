#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_FLAG_SET="true"
# shellcheck disable=SC2034
export CONST_IS_FLAG="__is_flag__"
# shellcheck disable=SC2034
export CONST_NOT_FLAG="__not_is_flag__"

# shellcheck disable=SC2034
export CONST_NO_VALIDATE="__no_validate"

# shellcheck disable=SC2034
export CONST_ARG_NOT_PASSED="__not_passed_arg__"
# shellcheck disable=SC2034
export CONST_ARG_PASSED="__arg_passed__"

# shellcheck disable=SC2329
function __no_validate() {
    local val="$1"
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
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
