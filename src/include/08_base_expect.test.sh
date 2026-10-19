#!/usr/bin/env bash

set -Eeuo pipefail

__PRIVATE_TEST_EXPECT_RES="true"
__PRIVATE_TEST_EXPECT_TIMEOUT="30"

declare -a __scripts_file_to_remove=()


function __prepare_script_file_and_run() {
    local run_test="$1"
    local script_content="$2"
    local expected_arr_name="$3"
    local exit_code="$4"

    echo_info "Run test '$run_test'"

    shift
    shift
    shift
    shift

    local script_file=""
    if ! script_file="$(mktemp -t "${run_test}.test.expect.sh.XXXXXXXX")"; then
        echo_error "Cannot create script_file for '$run_test'"
        __PRIVATE_TEST_EXPECT_RES="false"

        return 0
    fi

    __scripts_file_to_remove+=("$script_file")

    if ! chmod 755 "$script_file"; then
        echo_error "Cannot chmod script_file for '$run_test'"
        __PRIVATE_TEST_EXPECT_RES="false"

        return 0
    fi

    write_shebang_header "$script_file"
    {
        echo ""
        echo "$script_content"
    } >> "$script_file"

    local run_exit_code="0"
    if run_cmd_with_expect_script "$script_file" "$expected_arr_name" "$@"; then
        if num_eq "$exit_code" "0"; then
            echo_info "OK: run '$run_test' run command success"
            return 0
        else
            echo_error "FAIL: run '$run_test' return incorrect exit code 0, should be $exit_code"
            __PRIVATE_TEST_EXPECT_RES="false"
            return 0
        fi
    else
        run_exit_code="$?"
        if num_eq "$run_exit_code" "$exit_code"; then
            echo_info "OK: run '$run_test' run command failed with correct exit code '$exit_code'"
            return 0
        else
            echo_error "FAIL: run '$run_test' return incorrect exit code ${run_exit_code}, should be $exit_code"
            __PRIVATE_TEST_EXPECT_RES="false"
            return 0
        fi
    fi
}

function __run_test_no_grep_any() {
    local content="
echo \"Hello\"
echo \"World\" >&2
"
    local -a __expects_for_no_grep=(
        "action_get_exit||||Enter some"
    )

    __prepare_script_file_and_run "no_grep" "$content" "__expects_for_no_grep" "0"
}

function __run_test_no_grep_and_input_exit() {
    local content="
echo \"Hello\"
answ=""
echo -n \"Enter some: \"
read answ
echo \"Answer is: \"\${answ}\"\" >&2
echo "Done!"
read -r answ
"
    local -a __expects_for_no_grep=(
        "action_input||||Enter some: ||||Entered answer||||1"
        "action_get_exit||||Done!"
    )

    __prepare_script_file_and_run "grep_enter_and_exit" "$content" "__expects_for_no_grep" "143"
}

function __run_test_multiple_one_grep_and_exit() {
    local content="
trap_fun() {
    echo \"Got trap\"
    exit 0
}

trap trap_fun SIGTERM

echo \"Hello\"
answ1=""
echo -n \"Enter some: \"
read answ1
echo \"First answer is: \"\${answ1}\"\"
echo \"Do some\" >&2
answ2=""
echo -n \"Enter some: \"
read answ2
echo \"Second answer is: \"\${answ2}\"\" 
echo \"Another do\" >&2
echo \"Get third answer\"
answ3=""
echo -n \"Enter some: \"
read answ3
echo \"Third answer is: \"\${answ3}\"\" 
answ4=""
echo -n \"Enter some: \"
read -r answ4
"
    local -a __expects_for_no_grep=(
        "action_input||||Enter some: ||||First answer||||"
        "action_input||||Enter some: ||||Second answer||||"
        "action_input||||Enter some: ||||Third answer||||1"
        "action_get_exit||||Enter some: "
    )

    __prepare_script_file_and_run "multiple_one_grep_and_exit" "$content" "__expects_for_no_grep" "143"
}


echo_info "Run expected script tests"

# __enable_debug_log "true"

#__run_test_no_grep_any
#__run_test_no_grep_and_input_exit
__run_test_multiple_one_grep_and_exit


echo_info "Remove tests scripts:"
for ff in "${__scripts_file_to_remove[@]}"; do
    rm -fv "$ff" || true
done

if [[ "$__PRIVATE_TEST_EXPECT_RES" == "true" ]]; then
    echo_info "PASSED: expected script tests"
    exit 0
fi

echo_error "FAILED: expected script tests"
exit 1
