#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_TMPDIR_ARG="--tmp-dir"
# shellcheck disable=SC2034
CONST_TMPDIR_ENV="SYNC_FS_TMP_DIR"

# shellcheck disable=SC2329
function parse_and_apply_temp_dir_global_args() {
    if is_help_flag_set "$@"; then
        return 0
    fi

    local tmpdir=""

    if ! tmpdir="$(extract_value_argument_no_validate "$CONST_TMPDIR_ARG" "$CONST_TMPDIR_ENV" "$@")"; then
        echo_error "Passed tmp dir is incorrect"
        return 1
    fi

    if str_empty "$tmpdir"; then
        tmpdir="$CONST_FS_SYNC_TMP_DIR_DEFAULT"
    fi

    if ! sync_fs_set_tmp_dir "$tmpdir"; then
        echo_error "Cannot create temp dir '$tmpdir'"
        return 1
    fi

    echo_info "Tmp dir is $tmpdir"
    return 0    
}

# shellcheck disable=SC2329
function tmp_dir_help() {
    echo -e "
    ${CONST_COLOR_GREEN}Temp files options:${CONST_COLOR_NO}
    ${CONST_TMPDIR_ARG} PATH
      Path to save temp files and directories.
      If not exists, will create.
      Optional. Default $CONST_FS_SYNC_TMP_DIR_DEFAULT
      Env $CONST_TMPDIR_ENV for set."
}
