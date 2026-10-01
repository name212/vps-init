#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_FORCE_DEBUG="force_debug"

# shellcheck disable=SC2034
export PRIVATE_SCRIPT_DEBUG_ENABLED=""
# shellcheck disable=SC2034
export PRIVATE_SCRIPT_LOG_FILE=""

# shellcheck disable=SC2034
export CONST_LOG_LEVEL_DEBUG="debug"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_INFO="info"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_WARN="warn"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_ERROR="error"

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
    if ! dt="$(date +'%Y-%m-%d %H:%M:%S')"; then
        dt="N/A-DATE"
    fi

    # shellcheck disable=SC2155
    local escaped_msg="$(__escape_new_line "$msg")"

    echo "[$dt] || [$level]: $escaped_msg" >> "$PRIVATE_SCRIPT_LOG_FILE" || true
}

# shellcheck disable=SC2329
function echo_error() {
    echo_red "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_ERROR" "$1" || true
}

# shellcheck disable=SC2329
function echo_warn () {
    echo_yellow "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_WARN" "$1" || true
}

# shellcheck disable=SC2329
function echo_info () {
    echo_green "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_INFO" "$1" || true
}

# shellcheck disable=SC2329
function is_log_level_debug_enabled() {
    local force="${1:-}"

    if [[ "$force" == "$CONST_FORCE_DEBUG" || "$PRIVATE_SCRIPT_DEBUG_ENABLED" == "$CONST_FORCE_DEBUG" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function echo_debug() {
    local msg="${1:-}"
    local force="${2:-}"

    if is_log_level_debug_enabled "$force"; then
        echo -e "${CONST_COLOR_GRAY_LIGHT}${msg}${CONST_COLOR_NO}" >&2
    fi

    __write_to_log_file "$CONST_LOG_LEVEL_DEBUG" "$1" || true
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

    local log_id=""
    if ! log_id="$(__rand_str_n "10")"; then
        log_id="N/A"
    fi

    __write_to_log_file "$CONST_LOG_LEVEL_INFO" "Start log [id=$log_id]" || true

    return 0
}

# shellcheck disable=SC2329
function __tee_log_command_out() {
    local level="$1"

    shift

    if [[ "${#@}" == 0 ]]; then
        echo_warn "Command to tee out not found"
        return 0
    fi

    local cmd_run="$1"
    shift

    local output=""
    local ret_code="0"

    if ! output="$("$cmd_run" "$@" 2>&1)"; then
        ret_code="$?"
    fi

    if [[ "$ret_code" != "0" ]]; then
        echo_warn "'$cmd_run'... Returns error with ret code '$ret_code'"
    fi

    echo "$output" || true

    __write_to_log_file "$level" "$output" || true

    return 0
}

# shellcheck disable=SC2329
function tee_log_command_out_force() {
    __tee_log_command_out "$CONST_LOG_LEVEL_DEBUG" "$@"
    return 0
}

# shellcheck disable=SC2329
function tee_log_command_out() {
    if ! is_log_level_debug_enabled ""; then
        return 0
    fi

    __tee_log_command_out "$CONST_LOG_LEVEL_DEBUG" "$@"
    return 0
}