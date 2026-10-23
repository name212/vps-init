#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_EXPECT_ACTIONS_DELIMITER="||||"
# shellcheck disable=SC2034
CONST_EXPECT_ACTION_INPUT="action_input"
# shellcheck disable=SC2034
CONST_EXPECT_ACTION_INPUT_EXIT="action_input_exit"
# shellcheck disable=SC2034
CONST_EXPECT_ACTION_GET_EXIT="action_get_exit"
# shellcheck disable=SC2034
CONST_EXPECT_GREP_SHOULD_EXIT="_VrAUEE4vkhOP__should_exit_grep_RSUe5masA2o3_"

## expect command string
# ACTION||||Expected string||||Input for send [ ||||Sleep after input||||Timeout in seconds for get expected string ]
## for action action_get_exit
# action_get_exit||||Expected string [ ||||Sleep before exit||||Timeout in seconds for get expected string ]

# shellcheck disable=SC2034
CONST_EXPECT_PROCESS_KILLED_RET_CODE="143"

# shellcheck disable=SC2034
CONST_EXPECT_READ_ERROR_RET_CODE="1"
# shellcheck disable=SC2034
CONST_EXPECT_READ_TIMEOUT_RET_CODE="2"
# shellcheck disable=SC2034
CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE="3"
# shellcheck disable=SC2034
CONST_EXPECT_HAS_UNEXPECTED_STRINGS_RET_CODE="4"
# shellcheck disable=SC2034
CONST_EXPECT_HAS_UNEXPECTED_EXIT_RET_CODE="5"

# shellcheck disable=SC2329
function __kill_coprocess() {
    local should_exit_pid="$1"
    local echo_err_fun="$2"

    local kill_out=""

    if ! kill_out="$(kill -TERM "${should_exit_pid}" 2>&1)"; then
        "$echo_err_fun" "Cannot send kill -TERM '$should_exit_pid': $kill_out"
    fi
}

# shellcheck disable=SC2329
function __expect_validate_sleep() {
    local val="$1"

    if str_empty "$val"; then
        echo -n ""
        return 0
    fi

    if ! is_number_positive_or_zero "$val" > /dev/null; then
        return 1
    fi

    if num_eq "$val" "0"; then
        val=""
    fi

    echo -n "$val"

    return 0
}

# shellcheck disable=SC2329
function __input_to_coprocess() {
    local fd="$1"
    local next_input="$2"
    local next_sleep="${3:-}"
    local should_exit_pid="${4:-}"

    if ! str_empty "$next_input"; then
        echo_debug "Echo '$next_input' to fd '$fd'"
        echo "$next_input" >&"$fd"
    fi

    if ! str_empty "$next_sleep"; then
        echo_debug "Got sleep after input '$next_sleep'. Do sleep"
        sleep "$next_sleep"
    fi

    if ! str_empty "$should_exit_pid" ; then
        echo_debug "Got exit coprocess pid '$should_exit_pid'. Kill child process"
        __kill_coprocess "$should_exit_pid" "echo_debug"
    fi

    echo ""

    return 0
}

# shellcheck disable=SC2329
function run_cmd_with_expect_script() {
    local cmd="$1"
    local expect_script_arr_name="$2"

    if str_empty "$cmd"; then
        echo_error "Cmd for expect run not passed"
        return 255
    fi

    if is_array_empty "$expect_script_arr_name"; then
        echo_error "Expects command array '$expect_script_arr_name' not array or is empty for cmd '$cmd'"
        return 255
    fi

    shift
    shift

    local -n __expects="$expect_script_arr_name"

    local -a grep_for_input=()
    local -a input_for_grep=()
    local -a sleep_for_grep=()
    local -a sleep_wait_for_grep=()

    local -a grep_for_exit=()
    local -a input_for_exit=()
    local -a sleep_for_exit=()
    local -a sleep_wait_for_exit=()

    local -a __expect_parse_err=()

    local indx="-1"
    for cmd_str in "${__expects[@]}"; do
        ((indx++))

        local -a __split_expect_cmd=()
        if ! split_by "$CONST_EXPECT_ACTIONS_DELIMITER" "__split_expect_cmd" "$cmd_str"; then
            __expect_parse_err+=("Cannot split expected string $indx for cmd '$cmd'")
            continue
        fi

        if is_array_has_len "__split_expect_cmd" "1"; then
            __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': should len > 1")
            continue
        fi

        local expect_cmd="${__split_expect_cmd[0]}"
        local cmd_out="${__split_expect_cmd[1]}"

        case "$expect_cmd" in
            "$CONST_EXPECT_ACTION_INPUT")
                local len_exp="${#__split_expect_cmd[@]}"
                local input_for_ex=""
                local sleep_for_ex=""
                local sleep_for_wait=""
                case "$len_exp" in
                    3)
                        input_for_ex="${__split_expect_cmd[2]}"
                    ;;

                    4)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                    ;;

                    5)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                        sleep_for_wait="${__split_expect_cmd[4]}"
                    ;;

                esac

                local should_continue=""

                if ! sleep_for_ex="$(__expect_validate_sleep "$sleep_for_ex")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                fi

                if ! sleep_for_wait="$(__expect_validate_sleep "$sleep_for_wait")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep for wait '$sleep_for_wait'")
                fi

                if str_eq "$should_continue" "true"; then
                    continue
                fi

                grep_for_input+=("$cmd_out")
                input_for_grep+=("$input_for_ex")
                sleep_for_grep+=("$sleep_for_ex")
                sleep_wait_for_grep+=("$sleep_for_wait")
            ;;

            "$CONST_EXPECT_ACTION_INPUT_EXIT")
                local len_exp="${#__split_expect_cmd[@]}"
                local input_for_ex=""
                local sleep_for_ex=""
                local sleep_for_wait=""
                case "$len_exp" in
                    3)
                        input_for_ex="${__split_expect_cmd[2]}"
                    ;;
                    4)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                    ;;

                    5)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                        sleep_for_wait="${__split_expect_cmd[4]}"
                    ;;

                esac

                local should_continue=""

                if ! sleep_for_ex="$(__expect_validate_sleep "$sleep_for_ex")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                fi

                if ! sleep_for_wait="$(__expect_validate_sleep "$sleep_for_wait")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep for wait '$sleep_for_wait'")
                fi

                if str_empty "$input_for_ex"; then
                    should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': empty input")
                fi

                if str_eq "$should_continue" "true"; then
                    continue
                fi

                grep_for_exit+=("$cmd_out")
                input_for_exit+=("$input_for_ex")
                sleep_for_exit+=("$sleep_for_ex")
                sleep_wait_for_exit+=("$sleep_for_wait")
            ;;

            "$CONST_EXPECT_ACTION_GET_EXIT")
                local len_exp="${#__split_expect_cmd[@]}"
                local sleep_for_ex=""
                local sleep_for_wait=""
                case "$len_exp" in
                    3)
                        sleep_for_ex="${__split_expect_cmd[2]}"
                    ;;
                    4)
                        sleep_for_wait="${__split_expect_cmd[3]}"
                    ;;

                esac

                local should_continue="false"

                if ! sleep_for_ex="$(__expect_validate_sleep "$sleep_for_ex")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                fi

                if ! sleep_for_wait="$(__expect_validate_sleep "$sleep_for_wait")"; then
                     should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep for wait '$sleep_for_wait'")
                fi

                if str_eq "$should_continue" "true"; then
                    continue
                fi

                grep_for_exit+=("$cmd_out")
                input_for_exit+=("$CONST_EXPECT_GREP_SHOULD_EXIT")
                sleep_for_exit+=("$sleep_for_ex")
                sleep_wait_for_exit+=("$sleep_for_wait")
            ;;

            *)
                __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect command '$expect_cmd")
                continue
            ;;
        esac

    done

    if ! is_array_empty "__expect_parse_err"; then
        echo_error "Cannot parse expected commands array:"
        for __err_msg in "${__expect_parse_err[@]}"; do 
            echo_error "  ${__err_msg}"
        done

        return 1
    fi

    local len_grep_for_input="${#grep_for_input[@]}"
    local len_grep_for_exit="${#grep_for_exit[@]}"

    local child_pid=""

    function __sleep_and_exit_coprocess(){
        sleep 2
        exit "$1"
    }

    coproc __EXPECT_COPROC {
        sleep 2; 
        "$cmd" "$@" && __sleep_and_exit_coprocess "$?"; 
    } 2>&1

    child_pid="${__EXPECT_COPROC_PID}"

    echo_debug "Got pid $child_pid for cmd '$cmd'"

    local __expect_char=""

    local cur_grep_for_input="0"
    local cur_grep_for_exit="0"

    local cur_str=""

    local read_fd="${__EXPECT_COPROC[0]}"
    local write_fd="${__EXPECT_COPROC[1]}"

    local start_wait=""
    local cur_wait=""

    local res_ret_code="0"

    while true; do
        local wait_timeout_for_set="0"

        if ! num_eq "$len_grep_for_input" "0" && ! num_great_eq "$cur_grep_for_input" "$len_grep_for_input"; then
             has_grep="true"

             local cur_wait_for_grep="${sleep_wait_for_grep[$cur_grep_for_input]}"
             if ! str_empty "$cur_wait_for_grep"; then
                wait_timeout_for_set="$cur_wait_for_grep"
             fi
        fi

        if ! num_eq "$len_grep_for_exit" "0" && ! num_great_eq "$cur_grep_for_exit" "$len_grep_for_exit"; then
            local got_break=""
            for ii in $(seq "$cur_grep_for_exit" "$((len_grep_for_exit - 1))"); do
                local cur_wait_for_grep="${sleep_wait_for_exit[$ii]}"
                if ! str_empty "$cur_wait_for_grep"; then
                    if num_great_than "$cur_wait_for_grep" "$wait_timeout_for_set"; then
                        wait_timeout_for_set="$cur_wait_for_grep"
                    fi
                fi
            done
        fi

        if num_eq "$wait_timeout_for_set" "0"; then
            start_wait=""
            cur_wait=""
        else
            if str_empty "$start_wait"; then
                start_wait="$(get_unix_timestamp)"
            fi

            if str_empty "$cur_wait"; then
                cur_wait="$wait_timeout_for_set"
            fi
        fi

        local read_timeout="60"
        if ! str_empty "$cur_wait"; then
            read_timeout="$cur_wait"
            if ! str_empty "$start_wait" && is_timeout_exceeded "$cur_wait" "$start_wait"; then
                echo_error "Timeout ${cur_wait}'s for expect with index '$cur_grep_for_input' or exit exceeded. Kill process'"
                __kill_coprocess "$child_pid" "echo_warn"
                res_ret_code="$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
                break
            fi
        fi

        local ret_code_read="0"
        if read -t "$read_timeout" -N 1 -u "$read_fd" -r __expect_char 2>/dev/null; then
            true
        else
            ret_code_read="$?"
            if num_eq "$ret_code_read" "1"; then
                echo_debug "Got read error 1. Probable descriptor has closed or command exit"
                __kill_coprocess "$child_pid" "echo_debug"
                res_ret_code="$CONST_EXPECT_READ_ERROR_RET_CODE"
            else
                echo ""
                echo_warn "Has read error '$ret_code_read' or timeout. Terminate cmd '$cmd'"
                __kill_coprocess "$child_pid" "echo_warn"
                if ! str_empty "$cur_wait"; then
                    echo_warn "Timeout ${cur_wait}s for expect with index '$cur_grep_for_input' or exit exceeded"
                    res_ret_code="$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
                else
                    res_ret_code="$CONST_EXPECT_READ_WAIT_TIMEOUT_RET_CODE"
                fi 
            fi
            break
        fi

        local str_for_check="${cur_str}"
        if [[ "$__expect_char" != "$CONST_NEW_LINE" ]]; then
            cur_str="${cur_str}${__expect_char}"
            str_for_check="${cur_str}"
            printf "%s" "$__expect_char"
        else
            cur_str=""
            echo ""
        fi

        str_for_check="$(remove_color_commands_from_string "$str_for_check")"

        local has_grep=""
        if ! num_eq "$len_grep_for_input" "0" && ! num_great_eq "$cur_grep_for_input" "$len_grep_for_input"; then
             has_grep="true"

             if echo -n "$str_for_check" | grep -qP "${grep_for_input[$cur_grep_for_input]}"; then
                local next_input="${input_for_grep[$cur_grep_for_input]}"
                local next_sleep="${sleep_for_grep[$cur_grep_for_input]}"
                ((cur_grep_for_input++)) || true
                cur_str=""
                __input_to_coprocess "$write_fd" "$next_input" "$next_sleep"
                continue
             fi
        fi
        if ! num_eq "$len_grep_for_exit" "0" && ! num_great_eq "$cur_grep_for_exit" "$len_grep_for_exit"; then
            local got_break=""
            for ii in $(seq "$cur_grep_for_exit" "$((len_grep_for_exit - 1))"); do
                local next_input="${input_for_exit[$ii]}"
                local next_sleep="${sleep_for_exit[$ii]}"

                local cur_wait_for_grep="${sleep_wait_for_exit[$ii]}"

                if echo -n "$str_for_check" | grep -qP "${grep_for_exit[$ii]}"; then
                    if str_eq "$next_input" "$CONST_EXPECT_GREP_SHOULD_EXIT"; then
                        next_input=""
                    fi

                    ((cur_grep_for_exit++)) || true
                    cur_str=""
                    __input_to_coprocess "$write_fd" "$next_input" "$next_sleep" "$child_pid"
                    got_break="true"
                    wait_timeout_for_set="0"
                    break
                fi
            done
            has_grep="true"
            if str_eq "$got_break" "true"; then
                res_ret_code="0"
                break
            fi
        fi
        if ! str_eq "$has_grep" "true"; then
            __kill_coprocess "$child_pid" "echo_warn"
            break
        fi
    done

    local ret_code="0"
    local killed="false"

    if wait "$child_pid"; then
        echo_debug "Command '$cmd' ran successfully"
    else
        ret_code="$?"
        if num_eq "$ret_code" "$CONST_EXPECT_PROCESS_KILLED_RET_CODE"; then
            echo_debug "Command '$cmd' killed"
            killed="true"
        fi
    fi

    if str_eq "$killed" "true"; then
        return "$res_ret_code"
    fi

    if ! num_eq "$cur_grep_for_input" "$len_grep_for_input"; then
        if ! num_eq "$ret_code" "0"; then
            echo_warn "Command '$cmd' return with error code '$ret_code' and has unexpected strings for input"
            return "$CONST_EXPECT_HAS_UNEXPECTED_EXIT_RET_CODE"
        fi
        echo_warn "Command '$cmd' return with code '$ret_code' and has unexpected strings for input"
        return "$CONST_EXPECT_HAS_UNEXPECTED_STRINGS_RET_CODE"
    fi

    if num_less_than "$cur_grep_for_exit" "$len_grep_for_exit"; then
        if ! num_eq "$ret_code" "0"; then
            echo_warn "Command '$cmd' return with error code '$ret_code' and has unexpected strings for input"
            return "$CONST_EXPECT_HAS_UNEXPECTED_EXIT_RET_CODE"
        fi
        echo_warn "Command '$cmd' return with code '$ret_code' and has unexpected strings for exit"
        return "$CONST_EXPECT_HAS_UNEXPECTED_STRINGS_RET_CODE"
    fi

    if num_eq "$ret_code" "0"; then
        return 0
    fi

    return "$CONST_EXPECT_HAS_UNEXPECTED_EXIT_RET_CODE"
}
