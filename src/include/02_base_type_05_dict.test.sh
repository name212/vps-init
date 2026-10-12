#!/usr/bin/env bash

set -Eeuo pipefail

__PRIVATE_TEST_DICTS_RES="true"
__PRIVATE_DICT_TEST_SHOULD_OK="should ok"
__PRIVATE_DICT_TEST_NOT_SHOULD_OK="not should ok"
__PRIVATE_DICT_TEST_EMPTY_TEST_EMPTY="__empty_test_ok__"
__PRIVATE_DICT_TEST_EMPTY_TEST_NOT_EMPTY="__not_empty_test_ok__"

function _run_dict_len_test() {
    local dict_name="$1"
    local expected="$2"
    local dict_should_len="$3"

    local len_msg="dict '$dict_name':"
    local echo_fun="echo_info"

    local ret_code="0"
    if is_dict_has_len "$dict_name" "$dict_should_len"; then
        if [[ "$expected" == "$__PRIVATE_DICT_TEST_SHOULD_OK" ]]; then
            len_msg="OK: ${len_msg} Got correct len"
        else
            len_msg="FAIL: ${len_msg}"
            echo_fun="echo_error"
            __PRIVATE_TEST_DICTS_RES="false"
        fi
    else
        ret_code="$?"
        if [[ "$ret_code" == "255" ]]; then
            if [[ "$expected" == "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" ]]; then
                len_msg="OK: ${len_msg} Got not dict"
            else
                len_msg="FAIL: ${len_msg} Got dict"
                echo_fun="echo_error"
                __PRIVATE_TEST_DICTS_RES="false"
            fi
        else
            if [[ "$expected" == "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" ]]; then
                len_msg="OK: ${len_msg} Got incorrect len"
            else
                len_msg="FAIL: ${len_msg}"
                echo_fun="echo_error"
                __PRIVATE_TEST_DICTS_RES="false"
            fi
        fi
    fi

    "$echo_fun" "$len_msg"
} 

function _run_dict_is_empty_test() {
    local dict_name="$1"
    local expected="$2"

    local len_msg="dict '$dict_name':"
    local echo_fun="echo_info"

    local ret_code="0"
    if is_dict_empty "$dict_name"; then
        if [[ "$expected" == "$__PRIVATE_DICT_TEST_EMPTY_TEST_EMPTY" ]]; then
            len_msg="OK: ${len_msg} Got empty dict"
        else
            len_msg="FAIL: ${len_msg} Got not empty dict"
            echo_fun="echo_error"
            __PRIVATE_TEST_DICTS_RES="false"
        fi
    else
        ret_code="$?"
        if [[ "$ret_code" == "255" ]]; then
            if [[ "$expected" == "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" ]]; then
                len_msg="OK: ${len_msg} Got not dict"
            else
                len_msg="FAIL: ${len_msg} Got dict"
                echo_fun="echo_error"
                __PRIVATE_TEST_DICTS_RES="false"
            fi
        else
            if [[ "$expected" == "$__PRIVATE_DICT_TEST_EMPTY_TEST_NOT_EMPTY" ]]; then
                len_msg="OK: ${len_msg} Got not empty"
            else
                len_msg="FAIL: ${len_msg} Got not empty"
                echo_fun="echo_error"
                __PRIVATE_TEST_DICTS_RES="false"
            fi
        fi
    fi

    "$echo_fun" "$len_msg"
}

function _run_dicts_len_tests() {
    echo_green "Run 'is_dict_has_len' and 'is_dict_empty' tests"

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

    _run_dict_len_test "empty_dict" "$__PRIVATE_DICT_TEST_SHOULD_OK" "0"
    _run_dict_len_test "one_key_dict" "$__PRIVATE_DICT_TEST_SHOULD_OK" "1"
    _run_dict_len_test "multiple_keys_dict" "$__PRIVATE_DICT_TEST_SHOULD_OK" "3"

    _run_dict_len_test "empty_dict" "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" "1"
    _run_dict_len_test "one_key_dict" "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" "2"
    _run_dict_len_test "multiple_keys_dict" "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" "0"

    _run_dict_is_empty_test "empty_dict" "$__PRIVATE_DICT_TEST_EMPTY_TEST_EMPTY"
    _run_dict_is_empty_test "one_key_dict" "$__PRIVATE_DICT_TEST_EMPTY_TEST_NOT_EMPTY"
    _run_dict_is_empty_test "multiple_keys_dict" "$__PRIVATE_DICT_TEST_EMPTY_TEST_NOT_EMPTY"

    # shellcheck disable=SC2034
    local empty_str=""
    # shellcheck disable=SC2034
    local not_empty_str="aaaa"

    _run_dict_len_test "empty_str" "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" "0"
    _run_dict_len_test "not_empty_str" "$__PRIVATE_DICT_TEST_NOT_SHOULD_OK" "0"
}

function _run_dicts_key_tests() {
    echo_green "Run 'is_dict_has_key' tests"

    # shellcheck disable=SC2034
    local -A empty_dict=()

    local -A multiple_keys_dict=()
    multiple_keys_dict["first"]="first val"
    multiple_keys_dict["second"]="second val"
    # shellcheck disable=SC2034
    multiple_keys_dict["with spaces"]="with spaces val"

    local -a keys=("first" "second" "with spaces")

    for k in "${keys[@]}"; do
        if ! is_dict_has_key "empty_dict" "$k"; then
            echo_green "OK: 'empty_dict' has not key '$k'"
        else
            echo_red "FAIL: 'empty_dict' has key '$k', but should not have"
            __PRIVATE_TEST_DICTS_RES="false"
        fi
    done

    for k in "${keys[@]}"; do
        if is_dict_has_key "multiple_keys_dict" "$k"; then
            echo_green "OK: 'multiple_keys_dict' has key '$k'"
        else
            echo_red "FAIL: 'multiple_keys_dict' has not key '$k', but should have"
            __PRIVATE_TEST_DICTS_RES="false"
        fi
    done

    local -a not_found_keys=("a" "key" "my key")

    for k in "${not_found_keys[@]}"; do
        if ! is_dict_has_key "multiple_keys_dict" "$k"; then
            echo_green "OK: 'multiple_keys_dict' has not key '$k'"
        else
            echo_red "FAIL: 'multiple_keys_dict' has key '$k', but should not have"
            __PRIVATE_TEST_DICTS_RES="false"
        fi
    done

    for k in "${keys[@]}"; do
        local ret_code="0"
        if is_dict_has_key "keys" "$k"; then
            echo_red "FAIL: run is_dict_has_key on 'keys' array returns has key '$k', but should fail with internal error"
            __PRIVATE_TEST_DICTS_RES="false"
        else
            ret_code="$?"
            if [[ "$ret_code" == "255" ]]; then
                echo_green "OK: run is_dict_has_key on 'keys' array has key '$k', returns internal error"
            else
                 echo_red "FAIL: run is_dict_has_key on 'keys' array returns has not key '$k', but should fail with internal error"
                __PRIVATE_TEST_DICTS_RES="false"
            fi
        fi
    done
}

function _run_dict_diff_test() {
    local src_name="$1"
    local target_name="$2"
    local should_diff="$3"
    local diff_arr_name="$4"
    local deleted_arr_name="$5"

    local should_diff="false"

    if ! is_array_empty "diff_arr_name"; then
        should_diff="true"
    fi

    if ! is_array_empty "deleted_arr_name"; then
        should_diff="true"
    fi

    local -n run_diff_arr="$diff_arr_name"
    local -n run_deleted_arr="$deleted_arr_name"

    local -A

}

function _run_dicts_diff_tests() {
    local -A empty=()
    
    local -A one_key=()
    one_key["key"]="val"
    
    local -A multi_keys=()
    multi_keys["first"]="first val"
    multi_keys["second"]="second val"
    multi_keys["third"]="third_val"

    local -A multi_keys_one_change=()
    multi_keys["first"]="first val"
    multi_keys["second"]="second_val"
    multi_keys["third"]="third_val"

    local -A multi_keys_all_change=()
    multi_keys["first"]="first_val"
    multi_keys["second"]="second_val"
    multi_keys["third"]="third_val"

    local -A multi_keys_all_delete_one=()
    multi_keys["first"]="first val"
    multi_keys["third"]="third val"

    local -A multi_keys_all_delete_mul=()
    multi_keys["third"]="third val"

    local -A multi_keys_all_delete_and_change=()
    multi_keys["third"]="third_val"

    _run_dict_diff_test ""
}

_run_dicts_len_tests
_run_dicts_key_tests
#_run_dicts_diff_tests

if [[ "$__PRIVATE_TEST_DICTS_RES" == "true" ]]; then
    echo_info "PASSED: dicts tests"
    exit 0
fi

echo_error "FAIL: dicts tests"
exit 1