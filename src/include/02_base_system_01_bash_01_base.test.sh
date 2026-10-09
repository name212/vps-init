#!/usr/bin/env bash

set -Eeuo pipefail

_PRIVATE_TEST_BASE_BASH_RES="true"
_PRIVATE_SHOULD_ARRAY="array"
_PRIVATE_NOT_SHOULD_ARRAY="no array"
_PRIVATE_SHOULD_DICT="dict"
_PRIVATE_NOT_SHOULD_DICT="no dict"

declare -a _GLOBAL_ARRAY_EMPTY=()
declare -a _GLOBAL_ARRAY_NOT_EMPTY=("a")

declare -A _GLOBAL_DICT_EMPTY=()
declare -A _GLOBAL_DICT_NOT_EMPTY=()
_GLOBAL_DICT_NOT_EMPTY["key"]="val"

_GLOBAL_STR_EMPTY=""
_GLOBAL_STR_NOT_EMPTY="a"

function __check_test_is_array_dict() {
    local expect="$1"
    local current="$2"
    local var_name="$3"

    if [[ "$expect" == "$current" ]]; then
        echo_info "OK: '$var_name' should: $expect"
        return 0
    fi

    echo_error "FAIL: '$var_name' should: $expect but $current"
    _PRIVATE_TEST_BASE_BASH_RES="false"

    return 0
}

function _run_is_array_test() {
    # shellcheck disable=SC2034
    local -a array_empty=()
    # shellcheck disable=SC2034
    local -a array=("a" "b")

    # shellcheck disable=SC2034
    local str_empty=""
    # shellcheck disable=SC2034
    local str_not_empty="aa"

    local -A _test_cases_arrays=()

    _test_cases_arrays["array_empty"]="$_PRIVATE_SHOULD_ARRAY"
    _test_cases_arrays["array"]="$_PRIVATE_SHOULD_ARRAY"
    _test_cases_arrays["_GLOBAL_ARRAY_EMPTY"]="$_PRIVATE_SHOULD_ARRAY"
    _test_cases_arrays["_GLOBAL_ARRAY_NOT_EMPTY"]="$_PRIVATE_SHOULD_ARRAY"
    _test_cases_arrays["str_empty"]="$_PRIVATE_NOT_SHOULD_ARRAY"
    _test_cases_arrays["str_not_empty"]="$_PRIVATE_NOT_SHOULD_ARRAY"
    _test_cases_arrays["_GLOBAL_STR_EMPTY"]="$_PRIVATE_NOT_SHOULD_ARRAY"
    _test_cases_arrays["_GLOBAL_STR_NOT_EMPTY"]="$_PRIVATE_NOT_SHOULD_ARRAY"
    _test_cases_arrays["__not_declared__"]="$_PRIVATE_NOT_SHOULD_ARRAY"

    echo_info "Run 'is_array_var' tests"

    for var in "${!_test_cases_arrays[@]}"; do
        local should_be="${_test_cases_arrays[$var]}"
        if is_array_var "$var"; then 
            __check_test_is_array_dict "$should_be" "$_PRIVATE_SHOULD_ARRAY" "$var"
        else
            __check_test_is_array_dict "$should_be" "$_PRIVATE_NOT_SHOULD_ARRAY" "$var"
        fi
    done
}

function _run_is_dict_test() {
    # shellcheck disable=SC2034
    local -A dict_empty=()
    # shellcheck disable=SC2034
    local -A dict=()
    # shellcheck disable=SC2034
    dict["kkey"]="vval"

    # shellcheck disable=SC2034
    local str_in_dict_empty=""
    # shellcheck disable=SC2034
    local str_in_dict_not_empty="bb"

    local -A _test_cases_dicts=()

    _test_cases_dicts["dict_empty"]="$_PRIVATE_SHOULD_DICT"
    _test_cases_dicts["dict"]="$_PRIVATE_SHOULD_DICT"
    _test_cases_dicts["_GLOBAL_DICT_EMPTY"]="$_PRIVATE_SHOULD_DICT"
    _test_cases_dicts["_GLOBAL_DICT_NOT_EMPTY"]="$_PRIVATE_SHOULD_DICT"
    _test_cases_dicts["str_in_dict_empty"]="$_PRIVATE_NOT_SHOULD_DICT"
    _test_cases_dicts["str_in_dict_not_empty"]="$_PRIVATE_NOT_SHOULD_DICT"
    _test_cases_dicts["_GLOBAL_STR_EMPTY"]="$_PRIVATE_NOT_SHOULD_DICT"
    _test_cases_dicts["_GLOBAL_STR_NOT_EMPTY"]="$_PRIVATE_NOT_SHOULD_DICT"
    _test_cases_dicts["__not_declared_in_dict__"]="$_PRIVATE_NOT_SHOULD_DICT"

    echo_info "Run 'is_dict_var' tests"

    for var in "${!_test_cases_dicts[@]}"; do
        local should_be="${_test_cases_dicts[$var]}"
        if is_dict_var "$var"; then 
            __check_test_is_array_dict "$should_be" "$_PRIVATE_SHOULD_DICT" "$var"
        else
            __check_test_is_array_dict "$should_be" "$_PRIVATE_NOT_SHOULD_DICT" "$var"
        fi
    done
}

echo_info "Run argument bash base"

_run_is_array_test
_run_is_dict_test

if [[ "$_PRIVATE_TEST_BASE_BASH_RES" == "true" ]]; then
    echo_info "PASSED: bash base tests"
    exit 0
fi

echo_error "FAIL: bash base tests"
exit 1