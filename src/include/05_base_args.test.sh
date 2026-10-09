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
        should_arg="${_TEST_ARGS_CASES[$val]}"
        if is_argument_val "$val"; then
            __check_test_is_argument_val "$should_arg" "$__PRIVATE_SHOULD_ARG" "$val"
        else
            __check_test_is_argument_val "$should_arg" "$__PRIVATE_NOT_SHOULD_ARG" "$val"
        fi
    done
}

echo_info "Run argument tests"

_run_is_argument_val_tests

if [[ "$__PRIVATE_TEST_ARGS_RES" == "true" ]]; then
    echo_info "PASSED: arguments tests"
    exit 0
fi

echo_error "FAIL: arguments tests"
exit 1