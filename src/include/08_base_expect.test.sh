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
    if ! script_file="$(create_tmp_executable_file "${run_test}.test.expect.sh")"; then
         echo_error "Cannot create script_file for '$run_test'"
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

    __prepare_script_file_and_run "no_grep" "$content" "__expects_for_no_grep" "$CONST_EXPECT_HAS_UNEXPECTED_STRINGS_RET_CODE"
}

function __run_test_no_grep_any_exit_code() {
    local content="
echo \"Hello\"
echo \"World\" >&2
exit 3
"
    local -a __expects_for_no_grep=(
        "action_get_exit||||Enter some"
    )

    __prepare_script_file_and_run "no_grep_any_exit_code" "$content" "__expects_for_no_grep" "$CONST_EXPECT_HAS_UNEXPECTED_EXIT_RET_CODE"
}

function __run_test_no_grep_and_input_exit() {
    local content="
echo \"Hello\"
answ=""
echo -n \"Enter some: \"
read answ
echo \"Answer is: \"\${answ}\"\" >&2
echo \"Done!\"
read -r answ
"
    local -a __expects_for_no_grep=(
        "action_input||||Enter some: ||||Entered answer||||1"
        "action_get_exit||||Done!"
    )

    __prepare_script_file_and_run "grep_enter_and_exit" "$content" "__expects_for_no_grep" "0"
}

function __run_test_grep_without_input() {
    local content="
echo \"Hello\"
echo -en \"\033[1;33m[Some string]>\033[0m \"
read answ
"
    local -a __expects_grep_without_input=(
        "action_input||||Hello||||||||3"
        "action_get_exit||||\\]> \$||||0||||10"
    )

    __prepare_script_file_and_run "grep_without_input" "$content" "__expects_grep_without_input" "0"
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

    __prepare_script_file_and_run "multiple_one_grep_and_exit" "$content" "__expects_for_no_grep" "0"
}

# shellcheck disable=SC2140
__part_content="
trap_fun() {
    echo \"Got trap\"
    exit 0
}

trap trap_fun SIGTERM

has_error="\$\{1:-\}"
output_error_file="\$\{2:-\}"

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
if [ -n \"\$has_error\" ]; then
    err_answ=""
    echo -n \"Got Error. Enter some: \"
    read err_answ
    if [ -n \"\$output_error_file\" ]; then
        echo \"\$err_answ\" > \"\$output_error_file\"
    fi
    echo \"Error answer is: \"\${err_answ}\"\" 
fi
echo \"Get third answer\"
answ3=""
echo -n \"Enter some: \"
read answ3
echo \"Third answer is: \"\${answ3}\"\" 
answ4=""
echo -n \"Enter some: \"
read -r answ4
"

function __run_test_multiple_one_with_input_exit_no_exit() {

    local -a __expects_for_no_grep=(
        "action_input||||^Enter some: ||||First answer||||"
        "action_input||||^Enter some: ||||Second answer||||"
        "action_input_exit||||^Got Error\\. Enter some: ||||Error entered||||2"
        "action_input||||^Enter some: ||||Third answer||||1"
        "action_get_exit||||^Enter some: "
    )

    __prepare_script_file_and_run "multiple_one_with_input_exit_no_exit" "$__part_content" "__expects_for_no_grep" "0"
}

function __run_test_multiple_one_with_input_exit_with_exit() {

    local temp_err_out=""
    if ! temp_err_out="$(get_tmp_file_name "expect_err_out.txt" "true")"; then
        echo_error "FAIL: Internal error. Cannot create temp file for multiple_one_with_input_exit_with_exit test"
        __PRIVATE_TEST_EXPECT_RES="false"
        return 0
    fi

    local -a __expects_for_no_grep=(
        "action_input||||^Enter some: ||||First answer||||"
        "action_input||||^Enter some: ||||Second answer||||"
        "action_input_exit||||^Got Error\\. Enter some: ||||Error entered||||5"
        "action_input||||^Enter some: ||||Third answer||||1"
        "action_get_exit||||^Enter some: "
    )

    __prepare_script_file_and_run "multiple_one_with_input_exit_with_exit" "$__part_content" "__expects_for_no_grep" "0" "true" "$temp_err_out"

    if check_file_is_not_empty "$temp_err_out" > /dev/null; then
        if ! grep -q "Error entered" "$temp_err_out"; then
            echo_error "FAIL: Temp file for multiple_one_with_input_exit_with_exit test '$temp_err_out' not contains valid output 'Error entered'"
            echo_error "Output file content:"
            echo_error "'$(cat "$temp_err_out")'"
            __PRIVATE_TEST_EXPECT_RES="false"
        fi
    else
        echo_error "FAIL: Temp file for multiple_one_with_input_exit_with_exit test '$temp_err_out' empty or not found"
        __PRIVATE_TEST_EXPECT_RES="false"
    fi

    echo_info "Remove temp file for multiple_one_with_input_exit_with_exit test:"
    rm -fv "$temp_err_out" || true
}

function __run_test_no_grep_and_wait_timeout_exceeded() {
    local content="
echo \"Hello\"
echo \"World\" >&2
echo -n \"Enter please: \"
read answ
"
    local -a __expects_for_no_grep_timeout_exceeded=(
        "action_input||||Enter some||||Entered answer||||0||||5"
        "action_get_exit||||Enter some||||0||||4"
    )

    __prepare_script_file_and_run "no_grep_and_wait_timeout_exceeded" "$content" "__expects_for_no_grep_timeout_exceeded" "$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
}

function __run_test_grep_and_wait_timeout_not_exceeded() {
    local content="
echo \"Hello\"
echo \"World\" >&2
sleep 3
echo -n \"Enter please: \"
read answ
echo -n \"Entered answer: \$answ \"
sleep 2
echo -n \"Enter some: \"
read answ
"
    local -a __expects_grep_and_wait_timeout_not_exceeded=(
        "action_input||||Enter please: ||||Entered answer||||0||||10"
        "action_get_exit||||Enter some: ||||3||||4"
    )

    __prepare_script_file_and_run "grep_and_wait_timeout_not_exceeded" "$content" "__expects_grep_and_wait_timeout_not_exceeded" "0"
}


function __run_test_no_grep_and_wait_timeout_one_not_exceeded_and_exceeded() {
    local content="
echo \"Hello\"
echo \"World\" >&2
sleep 3
echo -n \"Enter please: \"
read answ1
echo  \"Answer 1 is: \$answ1\"
sleep 5
echo -n \"Enter please: \"
read answ2
echo  \"Answer 2 is: \$answ2\"
echo -n \"Enter some: \"
read answ
"
    local -a __grep_and_wait_timeout_one_not_exceeded_and_exceeded=(
        "action_input||||Enter please: ||||Entered answer||||0||||10"
        "action_input||||Enter please: ||||Entered answer another||||0||||3"
        "action_get_exit||||Enter some: ||||3||||4"
    )

    __prepare_script_file_and_run "no_grep_and_wait_timeout_exceeded" "$content" "__grep_and_wait_timeout_one_not_exceeded_and_exceeded" "$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
}

function __run_test_grep_all_timeouts_not_exceeded() {
    local content="
echo \"Hello\"
echo \"World\" >&2
sleep 3
echo -n \"Enter please: \"
read answ1
echo  \"Answer 1 is: \$answ1\"
sleep 5
echo -n \"Enter please: \"
read answ2
echo  \"Answer 2 is: \$answ2\"
sleep 2
echo -n \"Enter please: \"
read answ3
echo  \"Answer 3 is: \$answ3\"
"
    local -a __grep_all_timeouts_not_exceeded=(
        "action_input||||Enter please: ||||Entered answer||||0||||8"
        "action_input||||Enter please: ||||Entered answer another||||0"
        "action_input_exit||||Enter please: ||||3||||5"
    )

    __prepare_script_file_and_run "grep_all_timeouts_not_exceeded" "$content" "__grep_all_timeouts_not_exceeded" "0"
}

function __run_test_no_out_and_wait_timeout_exceeded() {
    local content="
read answ
"
    local -a __no_out_and_wait_timeout_exceeded=(
        "action_input||||Enter please: ||||Entered answer||||0||||5"
        "action_input||||Enter please: ||||Entered answer another||||0||||3"
        "action_get_exit||||Enter some: ||||3||||4"
    )

    __prepare_script_file_and_run "no_out_and_wait_timeout_exceeded" "$content" "__no_out_and_wait_timeout_exceeded" "$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
}


function __run_test_no_grep_and_wait_timeout_exceeded_forever_out() {
    local content="
echo \"Hello\"
for ii in \$(seq 0 10000000); do
    echo \"Print iter \$ii\"
    sleep 0.5
done
"
    local -a __no_grep_and_wait_timeout_exceeded_forever_out=(
        "action_input||||Enter some||||Entered answer||||0||||10"
        "action_get_exit||||Enter some||||0||||4"
    )

    __prepare_script_file_and_run "no_grep_and_wait_timeout_exceeded_forever_out" "$content" "__no_grep_and_wait_timeout_exceeded_forever_out" "$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
}

echo_info "Run expected script tests"

__run_test_no_grep_any
__run_test_no_grep_any_exit_code
__run_test_no_grep_and_input_exit
__run_test_grep_without_input
__run_test_multiple_one_grep_and_exit
__run_test_multiple_one_with_input_exit_no_exit
__run_test_multiple_one_with_input_exit_with_exit

__run_test_no_grep_and_wait_timeout_exceeded
__run_test_grep_and_wait_timeout_not_exceeded
__run_test_no_grep_and_wait_timeout_one_not_exceeded_and_exceeded
__run_test_grep_all_timeouts_not_exceeded
__run_test_no_out_and_wait_timeout_exceeded
__run_test_no_grep_and_wait_timeout_exceeded_forever_out

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
