#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
declare -A CONST_PRIVATE_SCREEN_PACKAGES=()

CONST_PRIVATE_SCREEN_PACKAGES["$SYS_PACKAGES_ENGINE_APT"]="screen"
CONST_PRIVATE_SCREEN_PACKAGES["$SYS_PACKAGES_ENGINE_APK"]="screen"

# shellcheck disable=SC2034
export CONST_SCREEN_REPLACED_VAL="__in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_SHOULD_REPLACED="__should_run_in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_NOT_RUN_IN_SCREEN="__not_run_in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_DEFAULT_SESS_NAME="server-init"

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
function screen_install() {
    # shellcheck disable=SC2155
    local pkg_manager="$(get_package_manager)"
    local screen_pkg=""
    if [[ -v CONST_PRIVATE_SCREEN_PACKAGES["$pkg_manager"] ]]; then
        screen_pkg="${CONST_PRIVATE_SCREEN_PACKAGES["$pkg_manager"]}"
    else
        echo_error "Cannot find screen package for package manager '$pkg_manager'"
        return 1
    fi

    if check_packages_installed "$screen_pkg"; then
        echo_debug "screen package '$screen_pkg' already installed"
        return 0
    fi

    if ! install_packages "$screen_pkg"; then
        echo_error "Cannot install screen package '$screen_pkg'"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function screen_replace_run_with_screen() {
    local need_screen_run="${1}"
    local screen_sess_name="${2:-}"
    local screen_records_dir="${3:-}"
    local script_file="${4:-}"

    shift
    shift
    shift
    shift

    local envs_set_str=""
    if envs_set_str="$(env)"; then
        local -a screen_envs_list=()
        if split_by_new_line "screen_envs_list" "$envs_set_str"; then
            for se_e in "${screen_envs_list[@]}"; do
                local screen_env=""
                if screen_env="$(echo "$se_e" | grep -i "_screen")"; then
                    true
                elif screen_env="$(echo "$se_e" | grep -iP "^term=")"; then
                    true
                else
                    continue
                fi
                echo_debug "Found screen env: '$screen_env'"
            done
        else
            echo_debug "Error split envs for out screen envs"
        fi
    else
        echo_debug "Error 'env' run for out screen envs"
    fi


    if [[ "$need_screen_run" == "$CONST_SCREEN_NOT_RUN_IN_SCREEN"  ]]; then
        echo_debug "Disable run in screen. Skip replace"
        return 0
    fi

    if [[ "${SYNC_SCREEN_REPLACED:-}" == "$CONST_SCREEN_REPLACED_VAL" || "${TERM:-}" == screen* ]]; then
        echo_debug "Already run with screen. Skip replace"
        return 0
    fi

    if ! screen_install; then
        echo_error "Cannot install screen"
        return 1
    fi

    if ! screen_sess_name="$(__screen_sess_prefix_default "$screen_sess_name" "$CONST_ARG_PASSED")"; then
        echo_error "Cannot apply screen session name"
        return 1
    fi


    if ! screen_records_dir="$(__screen_root_dir_default "$screen_records_dir" "$screen_sess_name")"; then
        echo_error "Cannot apply screen records log dir argument"
        return 1
    fi

    if [ ! -d "$screen_records_dir" ]; then
        if ! mkdir -p "$screen_records_dir"; then
            echo_error "Cannot create screen records log '$screen_records_dir'"
            return 1
        fi
    fi

    local dt=""
    if dt="$(date +'%Y-%m-%d_%H-%M-%S')"; then
        dt="${dt}-"
    else
        dt=""
    fi

    # shellcheck disable=SC2155
    export SYNC_ID="${screen_sess_name}-$(__rand_str_n "6")"

    export SYNC_SCREEN_SESS_NAME="$SYNC_ID"

    export SYNC_SCREEN_SESS_LOG_FILE="${screen_records_dir}/${dt}record-${SYNC_SCREEN_SESS_NAME}.log"

    if [ -z "$script_file" ]; then
        script_file="$CONST_SCRIPT_NAME"
    fi

    echo_debug "Star replace to screen"
    export SYNC_SCREEN_REPLACED="$CONST_SCREEN_REPLACED_VAL"

    local ret_code_screen="0"
    # shellcheck disable=SC2091
    # shellcheck disable=SC2154
    if $(exec screen -S "$SYNC_SCREEN_SESS_NAME" -L -Logfile "$SYNC_SCREEN_SESS_LOG_FILE" "$script_file" "$@"); then
        true
    else
        ret_code_screen="$?"
        echo_warn "screen returns error code $ret_code_screen"
    fi

    local exit_code="255"

    if [ -f "$SYNC_SCREEN_SESS_LOG_FILE" ]; then
        cat "$SYNC_SCREEN_SESS_LOG_FILE" || true
        echo_warn "Screen log: '$SYNC_SCREEN_SESS_LOG_FILE'. If need, remove with command"
        echo_warn "  rm -fv '$SYNC_SCREEN_SESS_LOG_FILE'"
        local exit_code_msg=""
        if exit_code_msg="$(grep -Po "${CONST_FAIL_MAIN_EXIT_CODE_PREFIX}\\d+" "$SYNC_SCREEN_SESS_LOG_FILE")"; then
            local exit_code_num=""
            if exit_code_num="$(echo "$exit_code_msg" | grep -Po "\\d+")"; then
                exit_code="$(trim_spaces "$exit_code_num")"
                echo_debug "Extracted exit code from screen log: '$exit_code'"
            fi
        else
            exit_code="0"
        fi
    fi

    exit "$exit_code"
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
    echo "
    Run via screen options:
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