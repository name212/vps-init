#!/usr/bin/env bash

set -Eeuo pipefail

__PRIVATE_TEST_ARRAYS_RES="true"
__PRIVATE_ARRAY_TEST_SHOULD_OK="should ok"
__PRIVATE_ARRAY_TEST_STRICT="__strict_fun__"
__PRIVATE_ARRAY_TEST_NOT_SHOULD_OK="not should ok"
__PRIVATE_ARRAY_TEST_EMPTY_TEST_EMPTY="__empty_test_ok__"
__PRIVATE_ARRAY_TEST_EMPTY_TEST_NOT_EMPTY="__not_empty_test_ok__"
__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST="__with_dest__"
__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK="__only_check__"

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

# shellcheck disable=SC2329
function _run_arrays_contains_all_with_dest_tests() { 
     # shellcheck disable=SC2034
    local test_arr="$1"
    local vals_arr_name="$2"
    local only_check="$3"

    shift
    shift
    shift

    local -a not_in_array=()
    for vv in "$@"; do
        not_in_array+=("$vv")
    done

    if [[ "$only_check" == "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" ]]; then
        echo_info "Run 'is_array_check_only_contains_all' on '$test_arr'"

        if is_array_check_only_contains_all "$test_arr" "$vals_arr_name"; then
            if is_array_empty "not_in_array"; then
                echo_green "OK: '$test_arr' contains all vals with only check"
                return 0
            else
                echo_error "FAIL: '$test_arr' should contains all vals, but not contains '${not_in_array[*]}' with only check"
                __PRIVATE_TEST_ARRAYS_RES="false"
                return 0
            fi
        else
            if ! is_array_empty "not_in_array"; then
                echo_green "OK: '$test_arr' not contains all vals with only check"
                return 0
            else
                echo_error "FAIL: '$test_arr' should not contains all vals, but contains all with only check"
                __PRIVATE_TEST_ARRAYS_RES="false"
                return 0
            fi
        fi
    fi

    # shellcheck disable=SC2034
    local -a has_not_arr=()

    echo_info "Run 'is_array_contains_all' on '$test_arr'"

    if is_array_contains_all "$test_arr" "$vals_arr_name" "has_not_arr"; then
        if is_array_empty "not_in_array"; then
            echo_green "OK: '$test_arr' contains all vals with not have dest"
            return 0
        else
            local -a not_should=()
            for ii in "${not_in_array[@]}"; do
                if ! is_array_has_val "has_not_arr" "$ii"; then
                    not_should+=("$ii")
                fi
            done

            if is_array_empty "not_should"; then
                echo_green "OK: '$test_arr' not contains vals with not have dest"
                return 0
            fi

            echo_error "FAIL: '$test_arr' should not contains all vals, but not contains should vals '${not_in_array[*]}' with not have dest"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        fi
    else
        if ! is_array_empty "not_in_array"; then
            local -a not_should=()
            for ii in "${not_in_array[@]}"; do
                if ! is_array_has_val "has_not_arr" "$ii"; then
                    not_should+=("$ii")
                fi
            done

            if is_array_empty "not_should"; then
                echo_green "OK: '$test_arr' not contains vals '${has_not_arr[*]}' with not have dest"
                return 0
            fi

            echo_error "FAIL: '$test_arr' should not contains all vals, but not contains should vals '${not_should[*]}' with not have dest"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        else
            echo_error "FAIL: '$test_arr' should not contains all vals, but should contains all with not have dest"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        fi
    fi
}

# shellcheck disable=SC2329
function _run_arrays_contains_all_via_args_tests() { 
     # shellcheck disable=SC2034
    local test_arr="$1"
    local vals_arr_name="$2"
    local only_check="$3"

    shift
    shift
    shift

    local -a not_in_array=()
    for vv in "$@"; do
        not_in_array+=("$vv")
    done

    local -n arrays_contains_all_via_args_vals="$vals_arr_name"
    local -a args=()
    for a_vv in "${arrays_contains_all_via_args_vals[@]}"; do
        args+=("$a_vv")
    done

    local -a not_in_array=()

    if [[ "$only_check" == "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" ]]; then
        if is_array_check_only_contains_all_via_args "$test_arr" "${args[@]}"; then
            echo_info "Run 'is_array_check_only_contains_all_via_args' on '$test_arr'"

            if is_array_empty "not_in_array"; then
                echo_green "OK: '$test_arr' contains all vals with only check via args"
                return 0
            else
                echo_error "FAIL: '$test_arr' should contains all vals, but not contains '${not_in_array[*]}' with only check via args"
                __PRIVATE_TEST_ARRAYS_RES="false"
                return 0
            fi
        else
            if ! is_array_empty "not_in_array"; then
                echo_green "OK: '$test_arr' not contains all should vals with only check via args"
                return 0
            else
                echo_error "FAIL: '$test_arr' should not contains all vals, but contains all with only check via args"
                __PRIVATE_TEST_ARRAYS_RES="false"
                return 0
            fi
        fi

        return 0
    fi

    # shellcheck disable=SC2034
    local -a has_not_arr=()

    echo_info "Run 'is_array_contains_all_via_args' on '$test_arr'"

    if is_array_contains_all_via_args "$test_arr" "has_not_arr" "${args[@]}"; then
        if is_array_empty "not_in_array"; then
            echo_green "OK: '$test_arr' contains all vals with not have dest check via args"
            return 0
        else
            local -a not_should=()
            for ii in "${not_in_array[@]}"; do
                if ! is_array_has_val "has_not_arr" "$ii"; then
                    not_should+=("$ii")
                fi
            done

            if is_array_empty "not_should"; then
                echo_green "OK: '$test_arr' not contains vals with not have dest check via args"
                return 0
            fi

            echo_error "FAIL: '$test_arr' should not contains all vals, but not contains should vals '${not_should[*]}' with not have dest check via args"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        fi
    else
        if ! is_array_empty "not_in_array"; then
            local -a not_should=()
            for ii in "${not_in_array[@]}"; do
                if ! is_array_has_val "has_not_arr" "$ii"; then
                    not_should+=("$ii")
                fi
            done

            if is_array_empty "not_should"; then
                echo_green "OK: '$test_arr' not contains vals '${has_not_arr[*]}' with not have dest check via args"
                return 0
            fi

            echo_error "FAIL: '$test_arr' should not contains all vals, but not contains should vals '${not_should[*]}' with not have dest check via args"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        else
            echo_error "FAIL: '$test_arr' should not contains all vals, but should contains all with not have dest check via args"
            __PRIVATE_TEST_ARRAYS_RES="false"
            return 0
        fi
    fi
}

function _run_arrays_contains_all_tests() {
    # shellcheck disable=SC2034
    local -a empty=()
    # shellcheck disable=SC2034
    local -a one_val=("first")
    # shellcheck disable=SC2034
    local -a mul_vals=("first" "second" "third val")

    # shellcheck disable=SC2034
    local -a one_val_should=("first")
    # shellcheck disable=SC2034
    local -a mul_val_should_mul=("third val" "first")
    # shellcheck disable=SC2034
    local -a mul_val_should_alls=("second" "third val" "first")

    # shellcheck disable=SC2034
    local -a one_val_not_should=("aaaaa")
    # shellcheck disable=SC2034
    local -a not_should_mul=("aaaaa" "bb bbb")
    # shellcheck disable=SC2034
    local -a not_should_all=("aaaaa" "bb bbb" "cccc")
    # shellcheck disable=SC2034
    local -a not_should_great=("aaaaa" "bb bbb" "cccc" "dddd")
    # shellcheck disable=SC2034
    local -a not_should_mixed_with_found=("first" "aaaaa" "third val")


    echo_info "Run 'is_array_contains_all' tests"

    _run_arrays_contains_all_with_dest_tests "one_val" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST"
    _run_arrays_contains_all_with_dest_tests "one_val" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "mul_val_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "mul_val_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "mul_val_should_alls" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "mul_val_should_alls" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK"

    _run_arrays_contains_all_with_dest_tests "empty" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "first" 
    _run_arrays_contains_all_with_dest_tests "empty" "one_val_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "first"

    _run_arrays_contains_all_with_dest_tests "empty" "mul_val_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "first" "third val"
    _run_arrays_contains_all_with_dest_tests "empty" "mul_val_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "first" "third val"
    
    _run_arrays_contains_all_with_dest_tests "empty" "mul_val_should_alls" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "first" "second" "third val" 
    _run_arrays_contains_all_with_dest_tests "empty" "mul_val_should_alls" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "first" "second" "third val"

    _run_arrays_contains_all_with_dest_tests "one_val" "mul_val_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "third val"
    _run_arrays_contains_all_with_dest_tests "one_val" "mul_val_should_alls" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "second" "third val"

    _run_arrays_contains_all_with_dest_tests "one_val" "one_val_not_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa"
    _run_arrays_contains_all_with_dest_tests "one_val" "one_val_not_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "one_val_not_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "one_val_not_should" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa" "bb bbb"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_mul" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa" "bb bbb"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_all" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa" "bb bbb" "cccc"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_all" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa" "bb bbb" "cccc"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_great" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa" "bb bbb" "cccc" "dddd"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_great" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa" "bb bbb" "cccc" "dddd"

    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_mixed_with_found" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_WITH_DEST" "aaaaa"
    _run_arrays_contains_all_with_dest_tests "mul_vals" "not_should_mixed_with_found" "$__PRIVATE_ARRAY_TEST_CONTAINS_ALL_ONLY_CHECK" "aaaaa"
}

_run_arrays_len_tests
_run_arrays_contains_all_tests

if [[ "$__PRIVATE_TEST_ARRAYS_RES" == "true" ]]; then
    echo_info "PASSED: arrays tests"
    exit 0
fi

echo_error "FAIL: arrays tests"
exit 1