#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_EXPECT_ACTIONS_DELIMITER="||||"
CONST_EXPECT_ACTION_INPUT="action_input"
CONST_EXPECT_ACTION_INPUT_EXIT="action_input_exit"
CONST_EXPECT_ACTION_GET_EXIT="action_get_exit"
CONST_EXPECT_GREP_SHOULD_EXIT="_VrAUEE4vkhOP__should_exit_grep_RSUe5masA2o3_"


function __kill_coprocess() {
    local should_exit_pid="$1"
    local echo_err_fun="$2"

    local kill_out=""

    if ! kill_out="$(kill -TERM "${should_exit_pid}" 2>&1)"; then
        "$echo_err_fun" "Cannot send kill -TERM '$should_exit_pid': $kill_out"
    fi
}

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
        __kill_coprocess "$should_exit_pid" "echo_info"
    fi

    echo ""

    return 0
}

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

    local -a grep_for_exit=()
    local -a input_for_exit=()
    local -a sleep_for_exit=()

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
                case "$len_exp" in
                    3)
                        input_for_ex="${__split_expect_cmd[2]}"
                    ;;

                    4)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                    ;;

                esac

                local should_continue=""
                if ! str_empty "$sleep_for_ex"; then
                    if ! is_number_positive_or_zero "$sleep_for_ex" > /dev/null; then
                        should_continue="true"
                        __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                    fi
                fi

                if str_empty "$input_for_ex"; then
                    should_continue="true"
                    __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': empty input")
                fi

                if str_eq "$should_continue" "true"; then
                    continue
                fi

                grep_for_input+=("$cmd_out")
                input_for_grep+=("$input_for_ex")
                sleep_for_grep+=("$sleep_for_ex")
            ;;

            "$CONST_EXPECT_ACTION_INPUT_EXIT")
                local len_exp="${#__split_expect_cmd}"
                local input_for_ex=""
                local sleep_for_ex=""
                case "$len_exp" in
                    3)
                        input_for_ex="${__split_expect_cmd[2]}"
                    ;;
                    4)
                        input_for_ex="${__split_expect_cmd[2]}"
                        sleep_for_ex="${__split_expect_cmd[3]}"
                    ;;

                esac

                local should_continue=""
                if ! str_empty "$sleep_for_ex"; then
                    if ! is_number_positive_or_zero "$sleep_for_ex" > /dev/null; then
                        should_continue="true"
                        __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                    fi
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
            ;;

            "$CONST_EXPECT_ACTION_GET_EXIT")
                local sleep_for_ex=""
                if num_eq "${#__split_expect_cmd}" "3"; then
                    sleep_for_ex="${__split_expect_cmd[2]}"
                    if ! str_empty "$sleep_for_ex"; then
                        if ! is_number_positive_or_zero "$sleep_for_ex" > /dev/null; then
                            __expect_parse_err+=("Incorrect expected string $indx for cmd '$cmd': incorrect sleep '$sleep_for_ex'")
                            continue
                        fi
                    fi
                fi

                grep_for_exit+=("$cmd_out")
                input_for_exit+=("$CONST_EXPECT_GREP_SHOULD_EXIT")
                sleep_for_exit+=("$sleep_for_ex")
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
        echo "Exit code corutine $1"
        exit "$1"
    }

    coproc __EXPECT_COPROC { sleep 2; "$cmd" "$@" && __sleep_and_exit_coprocess "$?"; } 2>&1

    child_pid="${__EXPECT_COPROC_PID}"

    echo_debug "Got pid $child_pid for cmd '$cmd'"

    local __expect_char=""

    local cur_grep_for_input="0"
    local cur_grep_for_exit="0"

    local cur_str=""

    #set -x

    local read_fd="${__EXPECT_COPROC[0]}"
    local write_fd="${__EXPECT_COPROC[1]}"

    while true; do
        local ret_code_read="0"
        if read -t 60 -N 1 -u "$read_fd" -r __expect_char; then
            true
        else
            ret_code_read="$?"
            if num_eq "$ret_code_read" "1"; then
                echo_debug "Got read error 1. Probable descriptor has closed or command exit"
                __kill_coprocess "$child_pid" "echo_debug"
            else
                echo ""
                echo_error "Has read error '$ret_code_read' or timeout. Terminate cmd '$cmd'"
                __kill_coprocess "$child_pid" "echo_warn"
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

        local has_grep=""

        if ! num_great_eq "$cur_grep_for_input" "$len_grep_for_input"; then
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

        if ! num_great_eq "$cur_grep_for_exit" "$len_grep_for_exit"; then
            local next_input="${input_for_exit[$cur_grep_for_exit]}"
            local next_sleep="${sleep_for_exit[$cur_grep_for_exit]}"

            if echo -n "$str_for_check" | grep -qP "${grep_for_exit[$cur_grep_for_exit]}"; then
                if str_eq "$next_input" "$CONST_EXPECT_GREP_SHOULD_EXIT"; then
                    next_input=""
                fi

                ((cur_grep_for_exit++)) || true
                cur_str=""
                __input_to_coprocess "$write_fd" "$next_input" "$next_sleep" "$child_pid"
                break
            fi
            has_grep="true"
        fi

        if ! str_eq "$has_grep" "true"; then
            __kill_coprocess "$child_pid" "echo_warn"
            break
        fi
    done

    local ret_code="0"

    if wait "$child_pid"; then
        echo_green "Command '$cmd' ran successfully"
    else
        ret_code="$?"
        echo_warn "Command '$cmd' exit with exit code '$ret_code'"
    fi

    return "$ret_code"
}
