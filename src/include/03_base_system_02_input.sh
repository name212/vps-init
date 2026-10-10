#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_NOT_ASK_VAL="__not_ask__"
# shellcheck disable=SC2034
export CONST_ASK_VAL="__should_ask__"

# shellcheck disable=SC2034
export CONST_READ_ERROR_RET_CODE="254"
# shellcheck disable=SC2034
export CONST_READ_ERROR_WITH_TIMEOUT_RET_CODE="255"

function __prepare_prompt_str() {
    local prompt="${1:-No prompt}"
    local yes_no_out="${2:-}"
    local timeout="${3:-}"

    local yes_no=""
    if [ -n "$yes_no_out" ]; then
        # shellcheck disable=SC2059
        yes_no="$(printf " \e${CONST_COLOR_GREEN}[y/n]\e${CONST_COLOR_NO}")"
    fi

    local timeout_msg=""
    if [ -n "$timeout" ]; then
        timeout_msg="[Read timeout ${timeout}s] "
    fi

    printf "> \e${CONST_COLOR_YELLOW}${timeout_msg}%s\e${CONST_COLOR_NO}${yes_no}: " "$prompt"
}

function __prepare_read_timeout_args() {
    local timeout="${1:-}"

    local timeout_args=""
    local res_timeout=""
    if [ -n "$timeout" ]; then
        if ! res_timeout="$(is_number_positive "$timeout")"; then
            echo_error "Incorrect timeout '$timeout'"
            return 1
        fi

        echo -n "-t $res_timeout"
        return 0
    fi

    echo -n ""
    return 0
}

function __read_error_handle() { 
    local timeout="${1:-}"

    local err_msg="Read error"
    local ret_code="$CONST_READ_ERROR_RET_CODE"
    
    if [ -n "$timeout" ]; then
        ret_code="$CONST_READ_ERROR_WITH_TIMEOUT_RET_CODE"
        err_msg="$err_msg or timeout ${timeout}s is reached"
    fi

    echo_error "${CONST_NEW_LINE}$err_msg"
    return "$ret_code"
}

# shellcheck disable=SC2329
function ask_user() {
    local prompt="${1:-No prompt}"
    local not_ask="${2:-no}"
    local timeout="${3:-}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi

    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "print_yn" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice_with_timeout() {
    local prompt="${1:-No prompt}"
    local timeout="${2:-}"
    
    shift
    shift

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi

    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

    for to_check in "$@"; do
        if [[ "$answer" == "$to_check" ]]; then
            echo -n "$answer"
            return 0
        fi
    done

    echo_error "Incorrect answer '$answer'"

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice() {
    local prompt="${1:-No prompt}"

    shift
    
    local answer=""
    local ret_code=""
    if answer="$(ask_user_choice_with_timeout "$prompt" "" "$@")"; then
        true
    else
        ret_code="$?"
        return "$ret_code"
    fi

    echo -n "$answer"
    return 0
}

# shellcheck disable=SC2329
function ask_user_raw() {
    local prompt="${1-:No prompt}"
    local validator="${2:-${CONST_NO_VALIDATE}}"
    local timeout="${3:-}"

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi
    
    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

    if [[ "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$answer"
        return 0
    fi

    local res=""

    if ! res="$($validator "$answer" "$CONST_ARG_PASSED")"; then
        echo_error "Incorrect answer '$answer': $res"
        return 1
    fi

    echo -n "$res"
    return 0
}
