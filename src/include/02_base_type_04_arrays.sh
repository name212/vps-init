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
        if [[ "$ar_val" == "$val" ]]; then
            return 0
        fi
    done

    return 1
}

# shellcheck disable=SC2329
function is_array_contains_all() {
    # shellcheck disable=SC2034
    local test_arr_name="$1"
    local vals_arr_name="$2"
    local has_not_arr_name="$3"

    if ! is_array_var "$test_arr_name"; then
        echo_error "Variable '$test_arr_name' is not array"
        return 255
    fi

    if ! is_array_var "$vals_arr_name"; then
        echo_error "Should contains variable '$vals_arr_name' is not array"
        return 255
    fi

    if ! is_array_var "$has_not_arr_name"; then
        echo_error "Has not vars dest variable '$has_not_arr_name' is not array"
        return 255
    fi

    if is_array_empty "$vals_arr_name"; then
        echo_error "Should be vals array '$vals_arr_name' is empty"
        return 255
    fi

    local -n is_array_contains_alls_vars_arr="$vals_arr_name"
    local -n is_array_contains_alls_not_contains_dest="$has_not_arr_name"

    indx="-1"
    for should_val in "${is_array_contains_alls_vars_arr[@]}"; do
        if ! is_array_has_val "$test_arr_name" "$should_val"; then
            ((indx++))
            # shellcheck disable=SC2034
            is_array_contains_alls_not_contains_dest["$indx"]="$should_val"
        fi
    done

    if [[ "$indx" == "-1" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function is_array_contains_all_via_args() {
    # shellcheck disable=SC2034
    local test_arr_name="$1"
    local has_not_arr_name="$2"

    shift
    shift

    local -a is_array_contains_all_via_args_should_vals=()
    for val in "$@"; do
        is_array_contains_all_via_args_should_vals+=("$val")
    done

    is_array_contains_all "$test_arr_name" "is_array_contains_all_via_args_should_vals" "$has_not_arr_name"
    return $?
}

# shellcheck disable=SC2329
function is_array_check_only_contains_all() { 
    # shellcheck disable=SC2034
    local test_arr_name="$1"
    local vals_arr_name="$2"

    # shellcheck disable=SC2034
    local -a is_array_check_only_contains_all_dest=()

    if is_array_contains_all "$test_arr_name" "$vals_arr_name" "is_array_check_only_contains_all_dest"; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function is_array_check_only_contains_all_via_args() { 
    # shellcheck disable=SC2034
    local test_arr_name="$1"
    shift

    local -a is_array_check_only_contains_all_via_args_vals=()
    for val in "$@"; do
        is_array_check_only_contains_all_via_args_vals+=("$val")
    done

    # shellcheck disable=SC2034
    local -a is_array_check_only_contains_all_via_args_dest=()

    is_array_contains_all "$test_arr_name" "is_array_check_only_contains_all_via_args_vals" "is_array_check_only_contains_all_via_args_dest"
    return $?
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
