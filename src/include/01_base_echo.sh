#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function echo_red(){
    echo -e "\033[1;31m$1\033[0m" >&2
}

# shellcheck disable=SC2329
function echo_green (){
    echo -e "\033[1;32m$1\033[0m" >&2
}

# shellcheck disable=SC2329
function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m" >&2
}

# shellcheck disable=SC2329
function echo_error(){
    echo_red "$1"
}

# shellcheck disable=SC2329
function echo_info (){
    echo_green "$1"
}

# shellcheck disable=SC2329
function echo_warn (){
    echo_yellow "$1"
}