#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_NOT_ASK_VAL="true"

function not_ask_arg_help() {
    echo "
-f|--force - not ask user for approve operation
    Also you can use NO_ASK=true env for set
"
}

function parse_not_ask() {
    local not_ask=""
    
    for arg in "$@"; do
        if [[ "$arg" == "--force" ]]; then
            echo -n "$CONST_NOT_ASK_VAL"
            return 0
        fi
    done

    echo -n "${NO_ASK-}"
    return 0
}

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

function echo_red(){
    echo_green -e "\033[1;31m$1\033[0m"
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m"
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m"
}