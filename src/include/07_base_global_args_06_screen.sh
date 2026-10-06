#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_SCREEN_ARG_ENABLE="--screen-enable-run-via-screen"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_ENABLE="SCREEN_ENABLE_RUN_VIA_SCREEN"

# shellcheck disable=SC2034
export CONST_SCREEN_ARG_RECORD_DIR="--screen-records-dir"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_RECORD_DIR="SCREEN_RECORDS_DIR"

# shellcheck disable=SC2034
export CONST_SCREEN_ARG_SESS_NAME="--screen-session-name-prefix"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_SESS_NAME="SCREEN_SESSION_NAME_PREFIX"

# shellcheck disable=SC2329
function __screen_sess_prefix_default() {
    local screen_sess_name="$1"
    local passed="${2:-}"

    if [[ "$screen_sess_name" == "" || "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        screen_sess_name="$CONST_SCREEN_DEFAULT_SESS_NAME"
    fi

    echo -n "$screen_sess_name"
    return 0
}

# shellcheck disable=SC2329
function __screen_root_dir_default() {
    local screen_records_dir="$1"
    local sess_name="${2}"

    if [ -z "$screen_records_dir" ]; then
        if [ -n "${HOME:-}" ]; then
            screen_records_dir="${HOME}/${sess_name}"
        else
            screen_records_dir="/root"
        fi
    fi

    echo -n "$screen_records_dir"
    return 0
}

# shellcheck disable=SC2329
function parse_screen_args() {
    local enable_screen_dest_name="$1"
    local screen_records_dir_dest_name="$2"
    local screen_sess_name_dest_name="$3"

    if [ -z "$enable_screen_dest_name" ]; then
        echo_error "enable screen dest name variable is empty"
        return 1
    fi

    if [ -z "$screen_records_dir_dest_name" ]; then
        echo_error "screen records dest name variable is empty"
        return 1
    fi

    if [ -z "$screen_sess_name_dest_name" ]; then
        echo_error "screen session name variable name is empty"
        return 1
    fi

    local -n enable_screen_ref="$enable_screen_dest_name"
    local -n screen_records_dir_ref="$screen_records_dir_dest_name"
    local -n screen_sess_name_ref="$screen_sess_name_dest_name"

    enable_screen_ref="$CONST_SCREEN_NOT_RUN_IN_SCREEN"
    screen_records_dir_ref=""
    screen_sess_name_ref=""

    shift
    shift
    shift

    if arg_flag_is_set "$CONST_SCREEN_ARG_ENABLE" "$CONST_SCREEN_ENV_ENABLE" "$@"; then
        # shellcheck disable=SC2034
        if ! screen_sess_name_ref="$(extract_value_argument "$CONST_SCREEN_ARG_SESS_NAME" "$CONST_SCREEN_ENV_SESS_NAME" "__screen_sess_prefix_default" "$@")"; then
            echo_error "Cannot extract screen session name  argument"
            return 1
        fi

        if ! screen_records_dir_ref="$(extract_value_argument_no_validate "$CONST_SCREEN_ARG_RECORD_DIR" "$CONST_SCREEN_ENV_RECORD_DIR" "$@")"; then
            echo_error "Cannot extract screen records log dir argument"
            return 1
        fi

        # shellcheck disable=SC2034
        if ! screen_records_dir_ref="$(__screen_root_dir_default "$screen_records_dir_ref" "$screen_sess_name_ref")"; then
            echo_error "Cannot apply screen records log dir argument"
            return 1
        fi
        # shellcheck disable=SC2034
        enable_screen_ref="$CONST_SCREEN_SHOULD_REPLACED"
    fi
    
    return 0
}

# shellcheck disable=SC2329
function screen_args_help() {
    echo -e "
    ${CONST_COLOR_GREEN}Run via GNU screen options:${CONST_COLOR_NO}
    $CONST_SCREEN_ARG_ENABLE
      By default, script run without GNU screen.
      If passed, enable run via screen.
      Env ${CONST_SCREEN_ENV_ENABLE}=true for set.
    $CONST_SCREEN_ARG_RECORD_DIR 'DIR_PATH'
      Dir for save output screen.
      If dir not exists, it will create.
      By default, \${HOME} is set, will be \${HOME}/\${session_name_prefix}, else /root
      Env $CONST_SCREEN_ENV_RECORD_DIR for set.
    $CONST_SCREEN_ARG_SESS_NAME 'NAME'
      Screen session name prefix.
      By default, $CONST_SCREEN_DEFAULT_SESS_NAME
      Env $CONST_SCREEN_ENV_SESS_NAME for set."
}
