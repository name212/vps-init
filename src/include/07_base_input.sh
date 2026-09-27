#!/usr/bin/env bash

set -Eeuo pipefail

function prepare_prompt_str() {
    local prompt="${1:-No prompt}"
    local yes_no_out="${2:-}"
    local yes_no=""
    if [ -n "$yes_no_out" ]; then
        # shellcheck disable=SC2059
        yes_no="$(printf " \e${CONST_COLOR_GREEN}[y/n]\e${CONST_COLOR_NO}")"
    fi
    printf "> \e${CONST_COLOR_YELLOW}%s\e${CONST_COLOR_NO}${yes_no}: " "$prompt"
}

# shellcheck disable=SC2329
function ask_user() {
    local prompt="${1-:No prompt}"
    local not_ask="${2-no}"
    local timeout="${3:-}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local timeout_args=""
    local res_timeout=""
    if [ -n "$timeout" ]; then
        if ! res_timeout="$(is_number_positive "$timeout")"; then
            echo_error "Incorrect timeout '$timeout'"
            return 1
        fi

        timeout_args="-t $res_timeout"
    fi

    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(prepare_prompt_str "$prompt" "print_yn")" answer; then
        local err_msg="Read error"
        if [ -n "$timeout_args" ]; then
            err_msg="$err_msg or timeout ${res_timeout}s is reached"
        fi

        echo_error "${CONST_NEW_LINE}$err_msg"
        return 255
    fi

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice() {
    local prompt="${1-:No prompt}"
    
    shift

    local answer=""

    # shellcheck disable=SC2162
    read -p "$(prepare_prompt_str "$prompt")" answer

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
function ask_user_raw() {
    local prompt="${1-:No prompt}"
    local validator="${2-${CONST_NO_VALIDATE}}"
    
    local answer=""

    # shellcheck disable=SC2162
    read -p "$(prepare_prompt_str "$prompt")" answer

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
