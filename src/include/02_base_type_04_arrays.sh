#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function is_array_has_len() {
    local var_name="$1"
    local should_len="$2"

    __is_array_dict_has_len "is_array_or_dict_var" "$should_len" "$var_name"
    return $?
}

# shellcheck disable=SC2329
function is_strict_array_has_len() {
    local var_name="$1"
    local should_len="$2"

    __is_array_dict_has_len "is_array_var" "$should_len" "$var_name"
    return $?
}

# shellcheck disable=SC2329
function is_array_empty() {
    local var_name="$1"

    is_array_has_len "$var_name" "0"
    return $?
}

# shellcheck disable=SC2329
function is_strict_array_empty() {
    local var_name="$1"

    is_strict_array_has_len "$var_name" "0"
    return $?
}

# shellcheck disable=SC2329
function is_array_has_val() {
    local var_name="$1"
    local val="$2"

    if ! is_array_var "$var_name"; then
        echo_error "Variable '$var_name' is not array"
        return 255
    fi

    local -n is_array_has_val_arr="$var_name"
    
    for ar_val in "${is_array_has_val_arr[@]}"; do
        if [[ "$arg" == "$ar_val" ]]; then
            return 0
        fi
    done

    return 1
}

# shellcheck disable=SC2329
function is_args_has_len() {
    local should_len="$1"
    shift

    if ! check_is_number "$should_len"; then
        echo_error "should len '$should_len' is not number"
        return 255
    fi

    local len_args="$#"
    
    num_eq "$len_args" "$should_len"
    return $?
}

# shellcheck disable=SC2329
function is_args_empty() {
    is_args_has_len "0" "$@"
    return $?
}

# shellcheck disable=SC2329
function is_args_has_val() {
    local val="$1"
    shift
    
    for arg in "$@"; do
        if [[ "$arg" == "$val" ]]; then
            return 0
        fi
    done

    return 1
}
