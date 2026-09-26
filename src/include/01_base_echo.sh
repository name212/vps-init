#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_NEW_LINE=$'\n'
# shellcheck disable=SC2034
CONST_COLOR_GREEN=$'\033[1;32m'
# shellcheck disable=SC2034
CONST_COLOR_YELLOW=$'\033[1;33m'
# shellcheck disable=SC2034
CONST_COLOR_RED=$'\033[1;31m'
# shellcheck disable=SC2034
CONST_COLOR_NO=$'\033[0m'

# shellcheck disable=SC2329
function echo_green (){
    echo -e "${CONST_COLOR_GREEN}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_yellow (){
    echo -e "${CONST_COLOR_YELLOW}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_red(){
    echo -e "${CONST_COLOR_RED}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_error(){
    echo_red "$1" >&2
}

# shellcheck disable=SC2329
function echo_info (){
    echo_green "$1" >&2
}

# shellcheck disable=SC2329
function echo_warn (){
    echo_yellow "$1" >&2
}