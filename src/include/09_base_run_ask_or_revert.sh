#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
DEFAULT_LOST_CONNECTION_WAIT_SEC="200"

# shellcheck disable=SC2329
function _do_action_print_screen_log() { 
    local log_file="${1:-}"

    if [ -z "$log_file" ]; then
        return 0
    fi

    echo_warn "Screen log: '$log_file'. If need, remove with command"
    echo_warn "  rm -fv '$log_file'"
}

# shellcheck disable=SC2329
function do_action_with_with_wait_to_continue() {
    local wait_reconnect_sec="$1"
    local action_name="$2"
    local new_address="$3"
    local action_func="$4"
    local action_func_args_arr_name="${5:-}"
    local revert_func="${6:-}"
    local revert_func_args_arr_name="${7:-}"

    if ! wait_reconnect_sec="$(is_number_positive "$wait_reconnect_sec")"; then
        echo_error "Wait timeout '$wait_reconnect_sec' is not positive number"
        return 1
    fi

    if [ -z "$action_name" ]; then
        echo_error "Action name not passed"
        return 1    
    fi

    if ! is_function_declared "$action_func"; then
        echo_error "Action function '$action_func' is not declared"
        return 1
    fi

    local -a __action_args=()

    if [ -n "$action_func_args_arr_name" ]; then
        if ! is_array_var "$action_func_args_arr_name"; then
            echo_error "Passed action function args array var '$action_func_args_arr_name' is not array"
            return 1
        fi

        local -n do_action_action_func_args_arr="$action_func_args_arr_name"

        for a_arg in "${do_action_action_func_args_arr[@]}"; do
            __action_args+=("$a_arg")
        done
    fi

    local -a __revert_args=()

    if [ -n "$revert_func" ]; then
        if ! is_function_declared "$revert_func"; then
            echo_error "Revert function '$revert_func' is not declared"
            return 1
        fi

         if [ -n "$revert_func_args_arr_name" ]; then
            if ! is_array_var "$revert_func_args_arr_name"; then
                echo_error "Passed revert function args array var '$revert_func_args_arr_name' is not array"
                return 1
            fi

            local -n do_action_revert_func_args_arr="$revert_func_args_arr_name"

            for r_arg in "${do_action_revert_func_args_arr[@]}"; do
                __revert_args+=("$r_arg")
            done
        fi
    fi

    local reconnect_address_msg=" "
    if [ -n "$new_address" ]; then
        reconnect_address_msg=" or reconnect (with re-plug if need) to '$new_address' "
    fi

    local continue_msg="$action_name done. You not lost connection${reconnect_address_msg}and we can continue?" 

    local screen_session=""
    if ! screen_session="$(screen_get_session)"; then
        screen_session=""
    fi

    local screen_record_log=""
    local screen_record_msg=""
    if screen_record_log="$(screen_get_session_log)"; then
        screen_record_msg="; cat '$screen_record_log'"
    fi

    echo_warn "Run $action_name"
    echo_warn "You can lost current connection!"
    echo ""
    echo_warn "If you do not see this message long time (20 seconds):"
    echo ""
    echo_warn "[Read timeout ${wait_reconnect_sec}s] '$continue_msg'"
    echo ""
    echo_warn "or ssh connection closed because use ServerAliveInterval and ServerAliveCountMax options"
    echo_warn "use instructions below:"
    echo ""
    
    if [ -n "$screen_session" ]; then
        echo_warn "Script started in screen with session name '$screen_session'"
        echo_warn "Script will wait ${wait_reconnect_sec}s to allow continue"
        if [ -n "$new_address" ]; then
            echo_warn "$(trim_spaces "$reconnect_address_msg")"
        fi
        echo_warn "With ask message '$continue_msg'."
        echo_warn "After connect, do be root and run:"
        echo_warn "  screen -d -r '$screen_session'${screen_record_msg}"
        echo_warn "and allow continue with enter 'y'"
    else
        local reconnect_msg=""
        if [ -n "$new_address" ]; then
            reconnect_msg=" with $(trim_spaces "$reconnect_address_msg")"
        fi
        echo_warn "Script started NOT in screen session"
        echo_warn "Re-connect to target${reconnect_msg}"
        echo_warn "Script wait ${wait_reconnect_sec}s to allow continue and exit script after timeout"
        echo_warn "Waiting exit script or kill it manually"
    fi

    echo ""
    echo_warn "If you disallow continue manually, revert function will not called!"
    echo ""

    echo_debug "Run action '$action_name' with '$action_func ${__action_args[*]}'"
    if ! "$action_func" "${__action_args[@]}"; then
        echo_error "Action '$action_name' returns error"
        return 1
    fi

    local continue_ret="0"
    if ask_user "$continue_msg" "$CONST_ASK_VAL" "$wait_reconnect_sec"; then
        true
    else
        continue_ret="$?"
        if [[ "$continue_ret" == "1" ]]; then
            echo_error "Disallow continue."
            _do_action_print_screen_log "$screen_record_log"
            echo_error "Exit script with error and not run revert function"
            exit 1
        fi

        echo_error "Timeout ${wait_reconnect_sec}s exceeded for action '$action_name'"
        if [ -n "$revert_func" ]; then
            echo_warn "Run revert function '$revert_func ${__revert_args[*]}'..."
            if "$revert_func" "${__revert_args[@]}"; then
                echo_warn "Revert function '$revert_func' ran successfully"
            else
                echo_error "Revert function '$revert_func' returns error!"
            fi
        else
            echo_warn "Revert function not passed. Skip revert"
        fi
        
        _do_action_print_screen_log "$screen_record_log"

        echo_error "Exit script with error"
        exit 1
    fi

    return 0
}