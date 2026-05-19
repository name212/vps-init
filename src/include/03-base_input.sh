#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function ask_user() {
    local prompt="$1"
    local not_ask="${2-no}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local answer=""

    read -p "${prompt} [y/n]: " answer

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice() {
    local prompt="$1"
    
    shift

    local answer=""

    read -p "${prompt}: " answer

    for to_check in "$@"; do
        if [[ "$answer" == "$to_check" ]]; then
            echo -n "$answer"
            return 0
        fi
    done

    echo_red "Incorrect answer '$answer'"

    return 1
}

# shellcheck disable=SC2329
function ask_user_raw() {
    local prompt="$1"
    local validator="${2-${CONST_NO_VALIDATE}}"
    
    local answer=""

    read -p "${prompt}: " answer

    if [[ "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$answer"
        return 0
    fi

    local res=""

    if ! res="$($validator "$answer" "$CONST_ARG_PASSED")"; then
        echo_red "Incorrect answer '$answer': $res"
        return 1
    fi

    echo -n "$res"
    return 0
}

function remove_begin_spaces() {
    local content="$1"
    while [[ "$content" == [[:space:]]* ]]; do
        content="${content#[[:space:]]}"
    done
    echo -n "$content"
}