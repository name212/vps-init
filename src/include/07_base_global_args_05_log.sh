#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_LOG_ARG_ENABLE_DEBUG="--log-enable-debug"
# shellcheck disable=SC2034
export CONST_LOG_ENV_ENABLE_DEBUG="LOG_ENABLE_DEBUG"
# shellcheck disable=SC2034
export CONST_LOG_ARG_FILE="--log-file"
# shellcheck disable=SC2034
export CONST_LOG_ENV_FILE="LOG_SCRIPT_FILE"
# shellcheck disable=SC2034
export CONST_LOG_ARG_UNIX_SECONDS="--log-add-unix-seconds-to-file-path"
# shellcheck disable=SC2034
export CONST_LOG_ENV_UNIX_SECONDS="LOG_UNIX_SECONDS_TO_PATH"

# shellcheck disable=SC2329
function parse_and_apply_log_settings() {
    if arg_flag_is_set "$CONST_LOG_ARG_ENABLE_DEBUG" "$CONST_LOG_ENV_ENABLE_DEBUG" "$@"; then
        __enable_debug_log "true"
    fi

    local log_file=""
    if ! log_file="$(extract_value_argument_no_validate "$CONST_LOG_ARG_FILE" "$CONST_LOG_ENV_FILE" "$@")"; then
        echo_error "Cannot extract log file argument"
        return 1
    fi

    if [ -n "$log_file" ]; then
        if arg_flag_is_set "$CONST_LOG_ARG_UNIX_SECONDS" "$CONST_LOG_ENV_UNIX_SECONDS" "$@"; then
            local log_file_suf=""
            if ! log_file_suf="$(date +%s)"; then
                echo_error "Cannot get suffix for log file"
                return 1
            fi
            log_file="${log_file}.${log_file_suf}"
        fi

        if ! __set_log_file "$log_file"; then
            echo_error "Cannot set log file '$log_file'"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function log_settings_help() {
    echo -e "
    ${CONST_COLOR_GREEN}Log settings:${CONST_COLOR_NO}
    $CONST_LOG_ARG_ENABLE_DEBUG
      If passed will output debug log information to terminal.
      Env ${CONST_LOG_ENV_ENABLE_DEBUG}=true for set.

    $CONST_LOG_ARG_FILE 'PATH'
      If set, all log include debug will write to file in format:
      [\$date] || [\$level]: \$msg
      Env $CONST_LOG_ENV_FILE

    $CONST_LOG_ARG_UNIX_SECONDS
      If set and pass log file path, will add unix time seconds
      as suffix of file path like (log file is /tmp/init-log.log):
        /tmp/init-log.log.1790520136
      Env ${CONST_LOG_ENV_UNIX_SECONDS}=true for set."
 }
