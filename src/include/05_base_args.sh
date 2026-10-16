#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_FLAG_SET="true"
# shellcheck disable=SC2034
CONST_IS_FLAG="__is_flag__"
# shellcheck disable=SC2034
CONST_NOT_FLAG="__not_is_flag__"

# shellcheck disable=SC2034
CONST_NO_VALIDATE="__no_validate"

# shellcheck disable=SC2034
CONST_ARG_NOT_PASSED="__not_passed_arg__"
# shellcheck disable=SC2034
CONST_ARG_PASSED="__arg_passed__"

# shellcheck disable=SC2329
function __no_validate() {
    local val="$1"
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function is_argument_val() {
    local val="$1"

    if [ -z "$val" ]; then
        return 1
    fi

    if [[ "$val" == -* ]]; then
        return 0
    fi

    return 1
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

    local validation_env_msg=""
    if [ -n "$env_name" ]; then
        validation_env_msg=" or env '$env_name'"
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

    if ! is_function_declared "$validator"; then
        echo_error "Internal error: '$validator' func not declared!"
        return 1
    fi

    local prepared
    if ! prepared="$($validator "$val" "$arg_passed")"; then
        echo_error "Validation failed from validator '$validator' for argument '$arg_name'${validation_env_msg}"
        return 1
    fi

    echo -n "$prepared"
    return 0
}

# shellcheck disable=SC2329
function filter_arguments() { 
    local args_to_filter_arr_name="$1"
    local dest_filtered_arr_name="$2"

    if ! is_array_var "$args_to_filter_arr_name"; then
        echo_error "Args to filter array var name '$args_to_filter_arr_name' is not array"
        return 1
    fi

    if ! is_array_var "$dest_filtered_arr_name"; then
        echo_error "Destination array var name '$dest_filtered_arr_name' is not array"
        return 1
    fi

    shift
    shift

    local -n __dest_filtered="$dest_filtered_arr_name"

    local indx="-1"

    while num_great_than "$#" "0"; do
        local cur_arg="$1"
        if is_array_has_val "$args_to_filter_arr_name" "$cur_arg"; then
            shift
            if ! num_eq "$#" "0"; then
                local cur_val="$1"
                if ! is_argument_val "$cur_val"; then
                    shift
                fi
            fi

            continue
        fi

        ((indx++)) || true
        __dest_filtered["$indx"]="$cur_arg"
        shift
    done

    return 0
}

# shellcheck disable=SC2329
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

# shellcheck disable=SC2329
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

# shellcheck disable=SC2329
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
