#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_FS_SYNC_TMP_DIR_DEFAULT="/root/tmp-sync"

# shellcheck disable=SC2329
function __create_fs_set_tmp_dir() {
    local path="$1"

    if is_path_exists "$path"; then
        if ! is_dir_path_exists "$path"; then
            echo_error "Cannot set sync tmp dir '$path'. Path exists and not dir"
            return 1
        fi
        return 0
    fi

    if ! mkdir -p "$path"; then
        echo_error "Cannot create sync tmp dir '$path'"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sync_fs_set_tmp_dir() {
    local path="$1"

    if str_eq "${__SYNC_FS_TMP_DIR:-}" "$path"; then
        return 0
    fi

    if ! __create_fs_set_tmp_dir "$path"; then
        return 1
    fi

    export __SYNC_FS_TMP_DIR="$path"

    return 0
}

# shellcheck disable=SC2329
function __run_mktemp() {
    if ! str_empty "${__SYNC_FS_TMP_DIR:-}"; then
        TMPDIR="$__SYNC_FS_TMP_DIR" mktemp "$@"
        return $?
    fi

    mktemp "$@"
    return $?
}

# shellcheck disable=SC2329
function get_tmp_file_name() {
    local prefix="${1:-}"
    local keep_file="${2:-false}"

    local mktmp_args=()

    local err_pref=""

    if ! str_empty "$prefix"; then
        err_pref=" for prefix '$prefix'"
        mktmp_args=("-t")
        mktmp_args+=("${prefix}.XXXXXXXX")
    fi

    local res_name=""
    if ! res_name="$(__run_mktemp "${mktmp_args[@]}")"; then
        echo_error "Cannot create temp file${err_pref}"
        return 1
    fi

    if str_empty "$res_name"; then
        echo_error "Cannot create temp file${err_pref} got empty file name"
        return 1
    fi

    if ! str_eq "$keep_file" "true"; then 
        if ! rm "$res_name"; then
            echo_error "Cannot remove temp file '$res_name'${err_pref} for only extract path"
            return 1
        fi
    fi

    echo -n "$res_name"
    return 0
}

# shellcheck disable=SC2329
function create_tmp_file() {
    local prefix="${1:-}"

    get_tmp_file_name "$prefix" "true"
    return $?
}

# shellcheck disable=SC2329
function temp_file_with_content() {
    local content="${1:-}"
    local prefix="${2:-}"

    local content_tmp_file=""
    if ! content_tmp_file="$(create_tmp_file "$prefix")"; then
        echo_error "Cannot create temp file for create content"
        return 1
    fi

    echo -n "$content" > "$content_tmp_file"

    echo -n "$content_tmp_file"

    return 0
}

# shellcheck disable=SC2329
function create_tmp_executable_file() {
    local prefix="${1:-}"

    local file_path=""
    if ! file_path="$(create_tmp_file "$prefix")"; then
        return 1
    fi

    if ! chmod 755 "$file_path"; then
        rm -f "$file_path" || true
        
        local err_msg_pref=""
        if ! str_empty "$prefix"; then
            err_msg_pref=" for prefix '$prefix'"
        fi

        echo_error "Cannot chmod to 755 temp file '$file_path'${err_msg_pref}"
        return 1
    fi

    echo -n "$file_path"

    return 0
}

# shellcheck disable=SC2329
function tmp_backup_file() {
    local path="$1"
    local prefix="${2:-}"

    if [ ! -f "$path" ]; then
        echo_error "Path '$path' is not file for backup"
        return 1
    fi

    local base=""
    if ! base="$(get_base_name_for_path "$path")"; then
        echo_error "Cannot get base name for '$path' for backup"
        return 1
    fi

    local perm=""
    if ! perm="$(get_path_permission_mode "$path")"; then
        echo_error "Cannot get permissions for '$path' for backup"
        return 1
    fi

    local owner=""
    if ! owner="$(get_path_owner "$path")"; then
        echo_error "Cannot get owner for '$path' for backup"
        return 1
    fi

    if ! str_empty "$prefix"; then
        prefix="${prefix}_"
    fi

    local bkp_path=""
    if ! bkp_path="$(create_tmp_file "${prefix}${base}")"; then
        echo_error "Cannot get backup file for '$path'"
        return 1
    fi

    if ! cp "$path" "$bkp_path"; then
        echo_error "Cannot cp backup file '$path' to '$bkp_path'"
        return 1
    fi

    if ! set_path_perm_with_owner "$bkp_path" "$perm" "$owner"; then
        rm -f "$bkp_path" || true
        echo_error "Cannot set perm for backup file '$bkp_path' to '$perm' and owner '$owner'"
        return 1
    fi

    echo -n "$bkp_path"

    return 0
}
