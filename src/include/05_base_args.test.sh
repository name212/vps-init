#!/usr/bin/env bash

set -Eeuo pipefail

__PRIVATE_TEST_ARGS_RES="true"
__PRIVATE_SHOULD_ARG="yes"
__PRIVATE_NOT_SHOULD_ARG="no"

function __check_test_is_argument_val() {
    local expect="$1"
    local current="$2"
    local val="$3"

    if [[ "$expect" == "$current" ]]; then
        echo_info "OK: '$val' should arg: $expect"
        return 0
    fi

    echo_error "FAIL: '$val' should arg: $expect but $current"
    __PRIVATE_TEST_ARGS_RES="false"

    return 0
}

function _run_is_argument_val_tests() {
    echo_info "Run is_argument_val tests"

    local -A _TEST_ARGS_CASES=()
    _TEST_ARGS_CASES["v"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["val"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["v-al"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["va--l"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["val-"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["val--"]="$__PRIVATE_NOT_SHOULD_ARG"
    _TEST_ARGS_CASES["-h"]="$__PRIVATE_SHOULD_ARG"
    _TEST_ARGS_CASES["--help"]="$__PRIVATE_SHOULD_ARG"
    _TEST_ARGS_CASES["--my-arg"]="$__PRIVATE_SHOULD_ARG"

    echo_info "Run 'is_argument_val' test"

    local empty=""
    local empty_should="$__PRIVATE_NOT_SHOULD_ARG"

    if is_argument_val "$empty"; then
        __check_test_is_argument_val "$empty_should" "$__PRIVATE_SHOULD_ARG" "$empty"
    else
        __check_test_is_argument_val "$empty_should" "$__PRIVATE_NOT_SHOULD_ARG" "$empty"
    fi

    for val in "${!_TEST_ARGS_CASES[@]}"; do
        local should_arg="${_TEST_ARGS_CASES[$val]}"
        if is_argument_val "$val"; then
            __check_test_is_argument_val "$should_arg" "$__PRIVATE_SHOULD_ARG" "$val"
        else
            __check_test_is_argument_val "$should_arg" "$__PRIVATE_NOT_SHOULD_ARG" "$val"
        fi
    done
}

function _run_filter_args_tests() {
    function __fail_filter_args_test() {
        __PRIVATE_TEST_ARGS_RES="false"
        echo_error "FAIL: $1"
        
        shift

        for __msg in "$@"; do
            echo_error "  $__msg"
        done
    }

    function __check_filter_args_test() {
        local __dest_args_name="$1"
        shift

        local -n __dest_args="$__dest_args_name"
        local __dest_len="${#__dest_args[@]}"

        if num_eq "$#" "0"; then
            if num_eq "$__dest_len" "0"; then
                echo_green "OK: filtered array empty as is should"
                return 0
            fi
            
            __fail_filter_args_test "Dest array '$__dest_args_name' should empty, but got ${__dest_len}: '${__dest_args[*]}'"
            return 0
        fi

        if ! num_eq "$#" "$__dest_len"; then
            __fail_filter_args_test "Dest array '$__dest_args_name' has incorrect len ${__dest_len}, should $#: '${__dest_args[*]}'"
            return 0
        fi

        local -a __errors=()

        local __indx="-1"
        for __should_arg in "$@"; do
            ((__indx++)) || true
            local __cur="${__dest_args[$__indx]}"
            if ! str_eq "$__should_arg" "$__cur"; then
                __errors+=("incorrect arg ${__indx}: got '$__cur', but should '$__should_arg'")
            fi
        done

        if is_array_empty "__errors"; then
            echo_green "Dest filtered array '$__dest_args_name' has correct args in order:"
            for ff in "${__dest_args[@]}"; do
                echo_green "  '$ff'"
            done
            return 0
        fi

        __fail_filter_args_test "Dest filtered array '$__dest_args_name' has filtered args or incorrect order" "${__errors[@]}"
        return 0
    }

    echo_info "Run argument tests"

    local first_filter_arg="--first-should-filter"
    local second_filter_arg="--second-should-filter"
    local flag_filter_arg="--flag-should-filter"

    # shellcheck disable=SC2034
    local -a one_arg=("$first_filter_arg")
    # shellcheck disable=SC2034
    local -a flag_arg=("$flag_filter_arg")
    # shellcheck disable=SC2034
    local -a all_args=("$first_filter_arg" "$second_filter_arg" "$flag_filter_arg")

    # shellcheck disable=SC2034
    local -a dest_no_args_filter_one=()
    filter_arguments "one_arg" "dest_no_args_filter_one"
    __check_filter_args_test "dest_no_args_filter_one"

    # shellcheck disable=SC2034
    local -a dest_no_args_filter_mul=()
    filter_arguments "all_args" "dest_no_args_filter_mul"
    __check_filter_args_test "dest_no_args_filter_mul"

    # shellcheck disable=SC2034
    local -a dest_all_args_filtered_only=()
    filter_arguments "all_args" "dest_all_args_filtered_only" "$first_filter_arg" "$second_filter_arg" "$flag_filter_arg"
    __check_filter_args_test "dest_all_args_filtered_only"

    # shellcheck disable=SC2034
    local -a dest_one_filtered_in_start_with_val=()
    filter_arguments "one_arg" "dest_one_filtered_in_start_with_val" "$first_filter_arg" "filtered val" "--first" "aaaa" "--flag"
    __check_filter_args_test "dest_one_filtered_in_start_with_val" "--first" "aaaa" "--flag"

    # shellcheck disable=SC2034
    local -a dest_one_filtered_in_middle_with_val=()
    filter_arguments "one_arg" "dest_one_filtered_in_middle_with_val" "--first" "aaaa" "val" "--flag" "$first_filter_arg" "filtered val" "--second" "bbbb" 
    __check_filter_args_test "dest_one_filtered_in_middle_with_val" "--first" "aaaa" "val" "--flag" "--second" "bbbb"

    # shellcheck disable=SC2034
    local -a dest_one_filtered_in_end_with_val=()
    filter_arguments "one_arg" "dest_one_filtered_in_end_with_val" "--first" "aaaa" "val" "--flag" "--second" "bbbb" "$first_filter_arg" "filtered val" 
    __check_filter_args_test "dest_one_filtered_in_end_with_val" "--first" "aaaa" "val" "--flag" "--second" "bbbb"

    # shellcheck disable=SC2034
    local -a dest_flag_filtered_in_start=()
    filter_arguments "flag_arg" "dest_flag_filtered_in_start" "$flag_filter_arg" "--first" "aaaa" "val" "$first_filter_arg" "filtered val" 
    __check_filter_args_test "dest_flag_filtered_in_start" "--first" "aaaa" "val" "$first_filter_arg" "filtered val"

    # shellcheck disable=SC2034
    local -a dest_flag_filtered_in_middle=()
    filter_arguments "flag_arg" "dest_flag_filtered_in_middle" "--first" "aaaa" "$flag_filter_arg" "--second" "val" 
    __check_filter_args_test "dest_flag_filtered_in_middle" "--first" "aaaa" "--second" "val"

    # shellcheck disable=SC2034
    local -a dest_flag_filtered_in_end=()
    filter_arguments "flag_arg" "dest_flag_filtered_in_end" "--first" "aaaa" "--second" "val" "$flag_filter_arg" 
    __check_filter_args_test "dest_flag_filtered_in_end" "--first" "aaaa" "--second" "val"

    # shellcheck disable=SC2034
    local -a dest_all_filtered_all=()
    filter_arguments "all_args" "dest_all_filtered_all" "--first" "aaaa" "$first_filter_arg" "filtered val" "--second" "second" "val" "$second_filter_arg" "filtered second" "$flag_filter_arg" 
    __check_filter_args_test "dest_all_filtered_all" "--first" "aaaa" "--second" "second" "val"

    # shellcheck disable=SC2034
    local -a dest_all_filtered_all_in_end=()
    filter_arguments "all_args" "dest_all_filtered_all_in_end" "--first" "aaaa" "--second" "second" "val" "$second_filter_arg" "filtered second" "$flag_filter_arg" "$first_filter_arg" "filtered val" 
    __check_filter_args_test "dest_all_filtered_all_in_end" "--first" "aaaa" "--second" "second" "val"

    # shellcheck disable=SC2034
    local -a dest_all_filtered_all_in_start=()
    filter_arguments "all_args" "dest_all_filtered_all_in_start" "$flag_filter_arg" "$second_filter_arg" "filtered second" "$first_filter_arg" "filtered val" "--first" "aaaa" "--second" "second" "val" 
    __check_filter_args_test "dest_all_filtered_all_in_start" "--first" "aaaa" "--second" "second" "val"

    # shellcheck disable=SC2034
    local -a dest_all_filtered_all_partial_passed=()
    filter_arguments "all_args" "dest_all_filtered_all_partial_passed" "$flag_filter_arg" "--first" "aaaa" "$first_filter_arg" "filtered val" "--second" "second" "val" 
    __check_filter_args_test "dest_all_filtered_all_partial_passed" "--first" "aaaa" "--second" "second" "val"
}

_run_is_argument_val_tests
_run_filter_args_tests

if [[ "$__PRIVATE_TEST_ARGS_RES" == "true" ]]; then
    echo_info "PASSED: arguments tests"
    exit 0
fi

echo_error "FAIL: arguments tests"
exit 1