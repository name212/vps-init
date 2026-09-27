#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_FORCE_DEBUG="force_debug"

# shellcheck disable=SC2034
export PRIVATE_SCRIPT_DEBUG_ENABLED=""
# shellcheck disable=SC2034
export PRIVATE_SCRIPT_LOG_FILE=""

# shellcheck disable=SC2034
export PRIVATE_CONST_LOG_LEVEL_DEBUG="debug"
# shellcheck disable=SC2034
export PRIVATE_CONST_LOG_LEVEL_INFO="info"
# shellcheck disable=SC2034
export PRIVATE_CONST_LOG_LEVEL_WARN="warn"
# shellcheck disable=SC2034
export PRIVATE_CONST_LOG_LEVEL_ERROR="error"

# shellcheck disable=SC2034
export CONST_NEW_LINE=$'\n'
# shellcheck disable=SC2034
export CONST_COLOR_GREEN=$'\033[1;32m'
# shellcheck disable=SC2034
export CONST_COLOR_YELLOW=$'\033[1;33m'
# shellcheck disable=SC2034
export CONST_COLOR_RED=$'\033[1;31m'
# shellcheck disable=SC2034
export CONST_COLOR_GRAY_LIGHT=$'\033[3;37m'
# shellcheck disable=SC2034
export CONST_COLOR_NO=$'\033[0m'

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
function __write_to_log_file () {
    local level="$1"
    local msg="$2"

    if [ -z "$PRIVATE_SCRIPT_LOG_FILE" ]; then
        return 0
    fi

    if [ ! -f "$PRIVATE_SCRIPT_LOG_FILE" ]; then
        return 0
    fi

    local dt=""
    if ! dt="$(date %Y-%m-%d %H:%M:%S)"; then
        dt="N/A-DATE"
    fi

    echo "[$dt] || [$level]: $msg" >> "$PRIVATE_SCRIPT_LOG_FILE" || true
}

# shellcheck disable=SC2329
function echo_error() {
    echo_red "$1" >&2
    __write_to_log_file "$PRIVATE_CONST_LOG_LEVEL_ERROR" "$1" || true
}

# shellcheck disable=SC2329
function echo_warn () {
    echo_yellow "$1" >&2
    __write_to_log_file "$PRIVATE_CONST_LOG_LEVEL_WARN" "$1" || true
}

# shellcheck disable=SC2329
function echo_info () {
    echo_green "$1" >&2
    __write_to_log_file "$PRIVATE_CONST_LOG_LEVEL_INFO" "$1" || true
}

# shellcheck disable=SC2329
function echo_debug() {
    local msg="${1:-}"
    local force="${2:-}"

    if [[ "$force" == "$CONST_FORCE_DEBUG" || "$PRIVATE_SCRIPT_DEBUG_ENABLED" == "$CONST_FORCE_DEBUG" ]]; then
        echo -e "${CONST_COLOR_GRAY_LIGHT}${msg}${CONST_COLOR_NO}" >&2
    fi

    __write_to_log_file "$PRIVATE_CONST_LOG_LEVEL_DEBUG" "$1" || true
}

# shellcheck disable=SC2329
function enable_debug_log () {
    local should_enabled="${1:-}"
    local val=""

    if [[ "$should_enabled" == "" || "$should_enabled" == "true" ]]; then
        echo_green "Debug logs output is enabled" >&2
        val="$CONST_FORCE_DEBUG"
    fi

    export PRIVATE_SCRIPT_DEBUG_ENABLED="$val"

    return 0
}

# shellcheck disable=SC2329
function set_log_file () {
    local log_file="${1}"

    if [ -z "$log_file" ]; then
        echo_red "Log file is empty" >&2
        return 1
    fi

    if [ -d "$log_file" ]; then
        echo_red "Log file '$log_file' is directory" >&2
        return 1
    fi

    if ! touch "$log_file"; then
        echo_red "Log file '$log_file' not touch" >&2
        return 1
    fi

    export PRIVATE_SCRIPT_LOG_FILE="$log_file"

    echo_green "Log file: '$PRIVATE_SCRIPT_LOG_FILE'" >&2

    __write_to_log_file "Start log" || true

    return 0
}