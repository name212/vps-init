#!/usr/bin/env bash

set -Eeuo pipefail

export __PRIVATE_TEST_PASSWORDS_RES="true"
export __CONST_PASSWORD_SHOULD_OK="__should_ok__"
export __CONST_PASSWORD_SHOULD_NOT_OK="__not_should_ok__"

function __test_run_one_password_fail() {
    local pass="$1"
    local msg="$2"
    local should_ok="$3"

    local add_msg="passed"
    if [[ "$should_ok" == "$__CONST_PASSWORD_SHOULD_NOT_OK" ]]; then
        add_msg="failed"
    fi

    echo_error "FAIL: password '$pass' should check ${add_msg}: ${msg}"
    echo ""
    __PRIVATE_TEST_PASSWORDS_RES="false"
}

function __test_run_one_password_ok() {
    local pass="$1"
    local msg="$2"

     local should_ok="$3"

    local add_msg="passed"
    if [[ "$should_ok" == "$__CONST_PASSWORD_SHOULD_NOT_OK" ]]; then
        add_msg="failed"
    else
        echo ""
    fi

    echo_info "OK: password '$pass' check ${add_msg}: $msg"
    echo ""
}

function __test_run_one_password_check() {
    local pass="$1"
    local msg="$2"
    local should_ok="$3"

    echo_green "Test: $msg with password '$pass'"

    if check_valid_password "$pass"; then
        if [[ "$should_ok" == "$__CONST_PASSWORD_SHOULD_NOT_OK" ]]; then
           __test_run_one_password_fail "$pass" "should not valid, but valid: $msg" "$should_ok"
           return 0
        fi

        __test_run_one_password_ok "$pass" "$msg" "$should_ok"
        return 0
    fi

    if [[ "$should_ok" == "$__CONST_PASSWORD_SHOULD_OK" ]]; then
        __test_run_one_password_fail "$pass" "should valid, but not valid: $msg" "$should_ok"
        return 0
    fi

    __test_run_one_password_ok "$pass" "$msg" "$should_ok"
    return 0
}

__test_run_one_password_check "" "empty" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "Ab1.zzadef" "min len" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "AAAAAAAA1111." "not contains lower" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "aaaaaaaa1111." "not contains upper" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "aaaaaaaaBBBB!" "not contains number" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "aaaaaaaaBBBB2" "not contains special" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "aaaaaaaaBBBB" "not contains special and number" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "AAAAAAAABBBB1" "not contains special and lower" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "112222222222," "not contains lower and upped" "$__CONST_PASSWORD_SHOULD_NOT_OK"

__test_run_one_password_check "Ab1.|,\\/?!;:[*]%\$^@><#&~" "Valid password" "$__CONST_PASSWORD_SHOULD_OK"
__test_run_one_password_check "Ab1.a6?a\$9,1@" "Valid with min len" "$__CONST_PASSWORD_SHOULD_OK"


check_valid_password_disable_specials

__test_run_one_password_check "Aaaaa22aaaB3" "Valid after disable specials" "$__CONST_PASSWORD_SHOULD_OK"

check_valid_password_enable_specials
check_valid_password_set_min_symbols "6"

__test_run_one_password_check "Ab1.z" "min len after set new min 6" "$__CONST_PASSWORD_SHOULD_NOT_OK"
__test_run_one_password_check "Ab1.zA" "Valid with min len 6" "$__CONST_PASSWORD_SHOULD_OK"
__test_run_one_password_check "Ab1.zA%deg" "Valid with min len 6 and len > min len" "$__CONST_PASSWORD_SHOULD_OK"

check_valid_password_reset_min_symbols

__test_run_one_password_check "Ab1.a6?a\$9,1@" "Valid with min len after reset" "$__CONST_PASSWORD_SHOULD_OK"


if [[ "$__PRIVATE_TEST_PASSWORDS_RES" == "true" ]]; then
    echo_info "Tests check passwords passed"
    exit 0
fi

echo_error "Tests check passwords FAILED!"
exit 1