#!/usr/bin/env bash

set -Eeuo pipefail

__PRIVATE_TEST_ARRAYS_RES="true"
__PRIVATE_ARRAY_TEST_SHOULD_OK="should ok"
__PRIVATE_ARRAY_TEST_STRICT="__strict_fun__"
__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK="not should ok"
__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY="__empty_test_ok__"
__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY="__not_empty_test_ok__"

function _run_arrays_len_test() {
    local array_name="$1"
    local expected="$2"
    local array_should_len="$3"
    local array_should_strict="${4:-}"

    local fun="is_array_has_len"
    local msg_suff="array/dict"
    if [[ "$array_should_strict" == "$__PRIVATE_ARRAY_TEST_STRICT" ]]; then
        fun="is_strict_array_has_len"
        msg_suff="array"
    fi

    local len_msg="run '$fun' on $msg_suff '$array_name':"
    local echo_fun="echo_info"

    local ret_code="0"
    if "$fun" "$array_name" "$array_should_len"; then
        if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_SHOULD_OK" ]]; then
            len_msg="OK: ${len_msg} Got correct len"
        else
            len_msg="FAIL: ${len_msg}"
            echo_fun="echo_error"
            __PRIVATE_TEST_ARRAYS_RES="false"
        fi
    else
        ret_code="$?"
        if [[ "$ret_code" == "255" ]]; then
            if [[ "$array_should_strict" == "$__PRIVATE_ARRAY_TEST_STRICT" ]]; then
                if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" ]]; then
                    len_msg="OK: ${len_msg} Got not array for '$fun'"
                else
                    len_msg="FAIL: ${len_msg} Got array for '$fun'"
                    echo_fun="echo_error"
                    __PRIVATE_TEST_ARRAYS_RES="false"
                fi
            fi
        else
            if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" ]]; then
                len_msg="OK: ${len_msg} Got incorrect len"
            else
                len_msg="FAIL: ${len_msg}"
                echo_fun="echo_error"
                __PRIVATE_TEST_ARRAYS_RES="false"
            fi
        fi
    fi

    "$echo_fun" "$len_msg"
} 

function _run_arrays_is_empty_test() {
    local array_name="$1"
    local expected="$2"
    local array_should_strict="${3:-}"

    local len_msg="dict '$array_name':"
    local echo_fun="echo_info"

    local fun="is_array_empty"
    local msg_suff="array/dict"
    if [[ "$array_should_strict" == "$__PRIVATE_ARRAY_TEST_STRICT" ]]; then
        fun="is_strict_array_empty"
        msg_suff="array"
    fi

    local ret_code="0"
    if "$fun" "$array_name"; then
        if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY" ]]; then
            len_msg="OK: ${len_msg} Got empty $msg_suff"
        else
            len_msg="FAIL: ${len_msg} Got not empty $msg_suff"
            echo_fun="echo_error"
            __PRIVATE_TEST_ARRAYS_RES="false"
        fi
    else
        ret_code="$?"
        if [[ "$ret_code" == "255" ]]; then
            if [[ "$array_should_strict" == "$__PRIVATE_ARRAY_TEST_STRICT" ]]; then
                if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" ]]; then
                    len_msg="OK: ${len_msg} Got not array"
                else
                    len_msg="FAIL: ${len_msg} Got array"
                    echo_fun="echo_error"
                    __PRIVATE_TEST_ARRAYS_RES="false"
                fi
            fi
        else
            if [[ "$expected" == "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY" ]]; then
                len_msg="OK: ${len_msg} Got not empty"
            else
                len_msg="FAIL: ${len_msg} Got not empty"
                echo_fun="echo_error"
                __PRIVATE_TEST_ARRAYS_RES="false"
            fi
        fi
    fi

    "$echo_fun" "$len_msg"
}

function _run_arrays_len_tests() {
    echo_green "Run 'is_dict_has_len' and 'is_dict_empty' tests"

    # shellcheck disable=SC2034
    local -a empty_array=()
    # shellcheck disable=SC2034
    local -a one_val_array=("val")
    # shellcheck disable=SC2034
    local -a multi_val_array=("first" "second" "third")

    # shellcheck disable=SC2034
    local -A empty_dict=()

    local -A one_key_dict=()
    # shellcheck disable=SC2034
    one_key_dict["key"]="val"

    local -A multiple_keys_dict=()
    multiple_keys_dict["first"]="first val"
    multiple_keys_dict["second"]="second val"
    # shellcheck disable=SC2034
    multiple_keys_dict["with spaces"]="with spaces val"

    _run_arrays_len_test "empty_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "0"
    _run_arrays_len_test "empty_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "0" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "empty_dict" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "0"
    _run_arrays_len_test "empty_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "one_val_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "1"
    _run_arrays_len_test "one_val_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "1" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "one_key_dict" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "1"
    _run_arrays_len_test "one_key_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "1" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "3"
    _run_arrays_len_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "3" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "multiple_keys_dict" "$__PRIVATE_ARRAY_TEST_SHOULD_OK" "3"
    _run_arrays_len_test "multiple_keys_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "3" "$__PRIVATE_ARRAY_TEST_STRICT"

    _run_arrays_len_test "empty_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "1"
    _run_arrays_len_test "empty_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "1" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "one_val_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0"
    _run_arrays_len_test "one_val_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "one_key_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "2"
    _run_arrays_len_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0"
    _run_arrays_len_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_len_test "multiple_keys_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0"

    _run_arrays_is_empty_test "empty_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY"
    _run_arrays_is_empty_test "empty_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_is_empty_test "empty_dict" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY"
    _run_arrays_is_empty_test "empty_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_is_empty_test "one_val_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY"
    _run_arrays_is_empty_test "one_val_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_is_empty_test "one_key_dict" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY"
    _run_arrays_is_empty_test "one_key_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_is_empty_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY"
    _run_arrays_is_empty_test "multi_val_array" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY" "$__PRIVATE_ARRAY_TEST_STRICT"
    _run_arrays_is_empty_test "multiple_keys_dict" "$__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY"
    _run_arrays_is_empty_test "multiple_keys_dict" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "$__PRIVATE_ARRAY_TEST_STRICT"

    # shellcheck disable=SC2034
    local empty_str=""
    # shellcheck disable=SC2034
    local not_empty_str="aaaa"

    _run_arrays_len_test "empty_str" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0"
    _run_arrays_len_test "not_empty_str" "$__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK" "0"
}

_run_arrays_len_tests

if [[ "$__PRIVATE_TEST_ARRAYS_RES" == "true" ]]; then
    echo_info "PASSED: dicts tests"
    exit 0
fi

echo_error "FAIL: dicts tests"
exit 1