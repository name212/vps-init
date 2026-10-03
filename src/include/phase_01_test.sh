#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["test_run"]="01"

# shellcheck disable=SC2329
function phase_test_run_run() {
    echo_debug "Start test run"
    if arg_flag_is_set "--test-run-fail" "TEST_RUN_FAIL" "$@"; then
        echo_error "Fail flag is set!"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    if ask_user "Continue?" "$not_ask"; then
        echo_green "Allow"
        return 0
    fi

    echo_warn "Disallow"
    return 1
}

# shellcheck disable=SC2329
function phase_test_run_help() {
    echo -n "
    Test run.
    No options.
"
}

# shellcheck disable=SC2329
function phase_test_run_disable_env() {
    echo -n "DISABLE_TEST_RUN"
}