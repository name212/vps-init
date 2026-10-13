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

# shellcheck disable=SC2329
function _run_dict_diff_print_diff() {
    local echo_fun="$1"
    local diff_name="$2"
    local deleted_name="$3"


    if ! is_array_empty "diff_dict_dest"; then
        echo_error "  changed:"
        for kk in "${!diff_dict_dest[@]}"; do
            echo_error "    '$kk' -> '${diff_dict_dest[$kk]}'"
        done
    fi

    if ! is_array_empty "deleted_diff_arr_dest"; then
        echo_error "  deleted:"
        for dk in "${deleted_diff_arr_dest[@]}"; do
            echo_error "    '$dk'"
        done
    fi
}

# shellcheck disable=SC2329
function __echo_error_with_shift() {
    echo_error "  $1"
}

# shellcheck disable=SC2329
function __echo_info_with_shift() {
    echo_info "  $1"
}


# shellcheck disable=SC2329
function _run_dict_diff_test() {
    local target_name="$1"
    local new_dict_name="$2"
    local diff_dict_name="$3"
    local deleted_arr_name="$4"

    local should_diff="false"

    if ! is_array_empty "$diff_dict_name"; then
        should_diff="true"
    fi

    if ! is_array_empty "$deleted_arr_name"; then
        should_diff="true"
    fi

    local -n run_diff_dict="$diff_dict_name"
    # shellcheck disable=SC2034
    local -n run_deleted_arr="$deleted_arr_name"

    local -A diff_dict_dest=()
    local -a deleted_diff_arr_dest=()

    if dict_get_diff "$target_name" "$new_dict_name" "diff_dict_dest" "deleted_diff_arr_dest"; then
        if [[ "$should_diff" == "false" ]]; then
            __PRIVATE_TEST_DICTS_RES="false"

            echo_error "FAIL: has diff between '$target_name' and '$new_dict_name', but should not:"
            dict_print_diff "diff_dict_dest" "deleted_diff_arr_dest" "__echo_error_with_shift" "$target_name"
            return 0
        else
            local -a errs_arr=()

            if ! is_dict_empty "diff_dict_dest" && is_array_empty "$diff_dict_name"; then
                errs_arr+=("diff has changed keys, but passed empty should diff")
            fi 

            for kv_str in "${run_diff_dict[@]}"; do
                local -a kv_arr=()
                if ! split_by_eq "kv_arr" "$kv_str"; then
                    __PRIVATE_TEST_DICTS_RES="false"
                    echo_error "Internal error: cannot split by '=' str '$kv_str'"
                    return 0
                fi

                local expected_key="${kv_arr[0]}"
                local expected_val=""
                if is_array_has_len "kv_arr" "2"; then
                    expected_val="${kv_arr[1]}"
                fi

                local changed_val=""
                if ! changed_val=$(dict_get_val "diff_dict_dest" "$expected_key"); then
                    errs_arr+=("not found changed key '$expected_key'")
                    continue
                fi

                if [[ "$expected_val" != "$changed_val" ]]; then
                    errs_arr+=("changed key '$expected_key' should have '$expected_val' but has '$changed_val'")
                    continue
                fi
            done

            if ! is_array_empty "$deleted_arr_name"; then
                local -a not_found_deleted=()
                if ! is_array_contains_all "deleted_diff_arr_dest" "$deleted_arr_name" "not_found_deleted"; then
                    errs_arr+=("not found deleted keys: '${not_found_deleted[*]}'")
                fi
            fi

            if ! is_array_empty "deleted_diff_arr_dest"; then
                if is_array_empty "$deleted_arr_name"; then
                    errs_arr+=("keys deleted, but not not any passed as should")
                else
                    local -a not_found_deleted_rev=()
                    if ! is_array_contains_all "deleted_diff_arr_dest" "$deleted_arr_name" "not_found_deleted_rev"; then
                        errs_arr+=("keys deleted, but not not passed as should: '${not_found_deleted_rev[*]}'")
                    fi
                fi
            fi

            if is_array_empty "errs_arr"; then
                echo_info "OK: diff between '$target_name' and '$new_dict_name' correct:"
                dict_print_diff "diff_dict_dest" "deleted_diff_arr_dest" "__echo_info_with_shift" "$target_name"
                return 0
            else
                __PRIVATE_TEST_DICTS_RES="false"
                echo_error "FAIL: diff between '$target_name' and '$new_dict_name' incorrect:"
                for err_msg in "${errs_arr[@]}"; do
                    echo_error "  $err_msg"
                done
                dict_print_diff "diff_dict_dest" "deleted_diff_arr_dest" "__echo_error_with_shift" "$target_name"
                return 0
            fi
        fi
    else
        if [[ "$should_diff" == "true" ]]; then
            __PRIVATE_TEST_DICTS_RES="false"
            echo_error "FAIL: has not diff between '$new_dict_name' and '$target_name', but should"
            return 0
        else
           echo_info "OK: has not diff between '$new_dict_name' and '$target_name'"
           return 0
        fi
    fi
}

function _run_dicts_diff_tests() {
    # shellcheck disable=SC2034
    local -A empty=()
    # shellcheck disable=SC2034
    local -A empty_another=()
    
    local -A one_key=()
    # shellcheck disable=SC2034
    one_key["key"]="val"

    local -A one_key_another=()
    # shellcheck disable=SC2034
    one_key_another["key"]="val"

    local -A one_key_add=()
    one_key_add["key"]="val"
    # shellcheck disable=SC2034
    one_key_add["second"]="2"

    local -A one_key_change=()
    # shellcheck disable=SC2034
    one_key_change["key"]="another"
    
    local -A multi_keys=()
    multi_keys["first key"]="first val"
    multi_keys["second"]="second val"
    # shellcheck disable=SC2034
    multi_keys["third"]="third_val"

    local -A multi_keys_another=()
    multi_keys_another["first key"]="first val"
    multi_keys_another["second"]="second val"
    # shellcheck disable=SC2034
    multi_keys_another["third"]="third_val"

    local -A multi_keys_one_change=()
    multi_keys_one_change["first key"]="first val"
    multi_keys_one_change["second"]="2"
    # shellcheck disable=SC2034
    multi_keys_one_change["third"]="third_val"

    local -A multi_keys_all_change=()
    multi_keys_all_change["first key"]="changed first"
    multi_keys_all_change["second"]="second!val"
    # shellcheck disable=SC2034
    multi_keys_all_change["third"]="third changed"

    local -A multi_keys_mul_add=()
    multi_keys_mul_add["first key"]="first val"
    multi_keys_mul_add["second"]="second val"
    multi_keys_mul_add["third"]="third_val"
    multi_keys_mul_add["new1"]="added"
    # shellcheck disable=SC2034
    multi_keys_mul_add["new 2"]="added another"

    local -A multi_keys_add_and_change=()
    multi_keys_add_and_change["first key"]="first val"
    multi_keys_add_and_change["second"]="second val"
    multi_keys_add_and_change["third"]="change third val"
    # shellcheck disable=SC2034
    multi_keys_add_and_change["new1"]="added"

    local -A multi_keys_delete_one=()
    multi_keys_delete_one["first key"]="first val"
    # shellcheck disable=SC2034
    multi_keys_delete_one["third"]="third_val"

    local -A multi_keys_delete_mul=()
    # shellcheck disable=SC2034
    multi_keys_delete_mul["third"]="third_val"

    local -A multi_keys_delete_mul_and_change=()
    # shellcheck disable=SC2034
    multi_keys_delete_mul_and_change["third"]="third was changed"

    local -A multi_keys_delete_and_change_add=()
    multi_keys_delete_and_change_add["third"]="third change val"
    # shellcheck disable=SC2034
    multi_keys_delete_and_change_add["new"]=""

    # shellcheck disable=SC2034
    local -a empty_should_dict_diff=()
    # shellcheck disable=SC2034
    local -a empty_should_deleted_diff=()

    _run_dict_diff_test "empty" "empty" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "empty" "empty_another" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "one_key" "one_key" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "one_key" "one_key_another" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "multi_keys" "multi_keys" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "multi_keys" "multi_keys_another" "empty_should_dict_diff" "empty_should_deleted_diff"
    _run_dict_diff_test "multi_keys_another" "multi_keys" "empty_should_dict_diff" "empty_should_deleted_diff"

    # shellcheck disable=SC2034
    local -a one_key_change_res=("key=another")
    _run_dict_diff_test "one_key" "one_key_change" "one_key_change_res" "empty_should_deleted_diff"

    # shellcheck disable=SC2034
    local -a one_key_change_res_rev=("key=val")
    _run_dict_diff_test "one_key_change" "one_key" "one_key_change_res_rev" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a one_key_add_res=("second=2")
    _run_dict_diff_test "one_key" "one_key_add" "one_key_add_res" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a one_key_delete_res=("key")
    _run_dict_diff_test "one_key" "empty" "empty_should_dict_diff" "one_key_delete_res"
    
    # shellcheck disable=SC2034
    local -a multi_key_one_change_res=("second=2")
    _run_dict_diff_test "multi_keys" "multi_keys_one_change" "multi_key_one_change_res" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a multi_key_multi_changes_res=("first key=changed first" "second=second!val" "third=third changed")
    _run_dict_diff_test "multi_keys" "multi_keys_all_change" "multi_key_multi_changes_res" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a multi_key_multi_add_res=("new1=added" "new 2=added another")
    _run_dict_diff_test "multi_keys" "multi_keys_mul_add" "multi_key_multi_add_res" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a multi_key_add_and_change_res=("new1=added" "third=change third val")
    _run_dict_diff_test "multi_keys" "multi_keys_add_and_change" "multi_key_add_and_change_res" "empty_should_deleted_diff"
    
    # shellcheck disable=SC2034
    local -a multi_key_delete_one_deleted=("second")
    _run_dict_diff_test "multi_keys" "multi_keys_delete_one" "empty_should_dict_diff" "multi_key_delete_one_deleted"
    
    # shellcheck disable=SC2034
    local -a multi_key_delete_multi_deleted=("first key" "second")
    _run_dict_diff_test "multi_keys" "multi_keys_delete_mul" "empty_should_dict_diff" "multi_key_delete_multi_deleted"
    
    # shellcheck disable=SC2034
    local -a multi_key_delete_and_change_deleted=("first key" "second")
    # shellcheck disable=SC2034
    local -a multi_key_delete_and_change_changed=("third=third was changed")
    _run_dict_diff_test "multi_keys" "multi_keys_delete_mul_and_change" "multi_key_delete_and_change_changed" "multi_key_delete_and_change_deleted"
    
    # shellcheck disable=SC2034
    local -a multi_key_delete_change_and_add_deleted=("first key" "second")
    # shellcheck disable=SC2034
    local -a multi_key_delete_change_and_add_changed=("third=third change val" "new=")
    _run_dict_diff_test "multi_keys" "multi_keys_delete_and_change_add" "multi_key_delete_change_and_add_changed" "multi_key_delete_change_and_add_deleted"
}

_run_dicts_len_tests
_run_dicts_key_tests
_run_dicts_diff_tests

if [[ "$__PRIVATE_TEST_DICTS_RES" == "true" ]]; then
    echo_info "PASSED: dicts tests"
    exit 0
fi

echo_error "FAIL: dicts tests"
exit 1