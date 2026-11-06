#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function delete_file() {
    if ! rm "$1"; then
        echo_error "$1 not deleted!"
        return 1
    fi

    echo_info "$1 deleted"
}

# shellcheck disable=SC2329
function temp_file_with_content() {
    local content="${1:-}"

    local content_tmp_file=""
    if ! content_tmp_file="$(mktemp)"; then
        echo_error "Cannot create temp file"
        return 1
    fi

    if [ -z "$content_tmp_file" ]; then
        echo_error "Cannot create temp file"
        return 1
    fi

    echo -n "$content" > "$content_tmp_file"

    echo -n "$content_tmp_file"

    return 0
}

# shellcheck disable=SC2329
function replace_file() {
    local src="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local remove_src="${4:-true}"
    local not_ask="${5:-false}"

    local ret_diff="0"

    if files_has_not_diff "$src" "$dest" "$title" "$CONST_OUT_DIFF_OR_HAS_DIFF"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if [[ "$ret_diff" == "255" ]]; then
        echo_error "Internal diff error"
        return 1
    fi

    if [[ "$ret_diff" == "0" ]]; then
        echo_info "No diff. Skip"
        return 0
    fi
    
    # prevent to break output
    sleep 1

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        if [[ "$remove_src" == "true" ]]; then
            echo_info "$title delete source $src"
            if ! rm "$src"; then
                echo_warn "$title source file $src not deleted!"
            fi
        fi
        echo_error "Disallow replace $dest"
        return 1
    fi

    if ! cp "$src" "$dest"; then
        echo_error "$title not replaced. Source $src not deleted"
        return 1
    fi

    if [[ "$remove_src" == "true" ]]; then
        echo_info "$title delete source $src"
        if ! rm "$src"; then
            echo_warn "$title source file $src not deleted!"
            return 0
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function sync_file_content() {
    local content="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local not_ask="${4:-false}"

    if [ -z "$dest" ]; then
        echo_error "File for sync not passed"
        return 1
    fi

    local temp_file=""

    if ! temp_file="$(temp_file_with_content "$content")"; then
        echo_error "Cannot create temp file for content"
        return 1
    fi

    if ! replace_file "$temp_file" "$dest" "$title" "true" "$not_ask"; then
        echo_error "Cannot sync file '$dest'"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sync_file_content_with_diff_ret_code() { 
    local content="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local not_ask="${4:-false}"

    if [ -z "$dest" ]; then
        echo_error "File for sync not passed"
        return 255
    fi

    local temp_file=""

    if ! temp_file="$(temp_file_with_content "$content")"; then
        echo_error "Cannot create temp file for content"
        return 255
    fi

    if files_has_not_diff "$temp_file" "$dest" "$title" "false"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if [[ "$ret_diff" == "255" ]]; then
        echo_error "Internal diff error"
        return 255
    fi

    if [[ "$ret_diff" == "0" ]]; then
        return 0
    fi

    if ! replace_file "$temp_file" "$dest" "$title" "true" "$not_ask"; then
        echo_error "Cannot sync file '$dest'"
        return 255
    fi

    return 1
}

# shellcheck disable=SC2329
function set_path_perm_with_owner() {
    local path="$1"
    local perm="$2"
    local owner="${3:-}"

    local full_path=""
    if ! full_path="$(realpath "$path")"; then
        echo_error "Cannot get full path for '$path' for set owner and permissions"
        return 1
    fi

    if ! check_is_permission_oct_valid "$perm" > /dev/null; then
        echo_error "Invalid permission mode '$perm' for path '$path'"
        return 1
    fi

    if ! str_empty "$owner"; then
        if ! check_is_chown_str_valid "$owner" > /dev/null; then
            echo_error "Invalid owner '$owner' for path '$path'"
            return 1
        fi

        if ! chown "$owner" "$full_path"; then
            echo_error "Cannot chown path '$full_path' to '$owner'"
            return 1
        fi
    fi

    if ! chmod "$perm" "$full_path"; then
        echo_error "Cannot chmod path '$full_path' to '$perm'"
        return 1
    fi

    return 0
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
    if ! res_name="$(mktemp "${mktmp_args[@]}")"; then
        echo_error "Cannot create temp file${err_pref}"
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
function create_tmp_executable_file() {
    local prefix="${1:-}"

    local file_path=""
    if ! file_path="$(get_tmp_file_name "$prefix" "true")"; then
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
function set_only_user_perm_for_path() {
    local path_to_set="$1"
    local user_for_set="$2"
    local group_for_set="${3:-}"

    if str_empty "$path_to_set"; then
        echo_error "Path for set path permissions not pass as first arg"
        return 1
    fi

    if str_empty "$user_for_set"; then
        echo_error "User set file permissions for path '$path_to_set' not pass"
        return 1
    fi

    if str_empty "$group_for_set"; then
        group_for_set="$user_for_set"
    fi

    local full_path=""

    if ! full_path="$(realpath "$path_to_set")"; then
        echo_error "Cannot extract real path for '$path_to_set'"
        return 1
    fi

    local perm=""

    if [ -d "$full_path" ]; then
        if str_eq "$user_for_set" "$group_for_set"; then
            perm="700"
        else
            perm="770"
        fi
    else
        if str_eq "$user_for_set" "$group_for_set"; then
            perm="600"
        else
            perm="660"
        fi
    fi

    if str_empty "$perm"; then
        echo_error "Internal error: cannot resolve chmod perm for path '$path_to_set'"
        return 1
    fi

    local chown_user="${user_for_set}:${group_for_set}"

    if ! set_path_perm_with_owner "$full_path" "$perm" "$chown_user"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function set_only_root_perm_for_path() {
    local path_to_set="$1"

    set_only_user_perm_for_path "$path_to_set" "root"
    return $?
}

# shellcheck disable=SC2329
function __run_stat_with_format() {
    local path="$1"
    local format="$2"

    if str_empty "$path"; then
        echo_error "Path for run stat is empty"
        return 1
    fi

    if str_empty "$format"; then
        echo_error "Format for run stat is empty for '$path'"
        return 1
    fi

    local out=""
    if ! out="$(stat  --format "%a" "$path")"; then
        echo_error "Cannot run stat for '$path'"
        return 1
    fi

    echo -n "$out"
    return 0
}

# shellcheck disable=SC2329
function get_path_permission_mode() {
    local path="$1"

    local perm=""
    if ! perm="$(__run_stat_with_format "$path" "%a")"; then
        echo_error "Cannot get permission mode for '$path'"
        return 1
    fi

    echo -n "$perm"
    return 0
}

# shellcheck disable=SC2329
function get_path_owner() {
    local path="$1"

    local owner=""
    if ! owner="$(__run_stat_with_format "$path" "%U:%G")"; then
        echo_debug "Cannot get owner for '$path' in human format. Try get ids"
        if ! owner="$(__run_stat_with_format "$path" "%u:%g")"; then
            echo_error "Cannot get owner for path '$path'"
            return 1
        fi
    fi

    echo -n "$owner"
    return 0
}

# shellcheck disable=SC2329
function get_base_name_for_path() {
    local path="$1"

    local full=""
    if ! full="$(realpath "$path")"; then
        echo_error "Cannot get full path '$path'"
        return 1
    fi

    local base=""
    if ! base="$(basename "$full")"; then
        echo_error "Cannot get base name for '$path'"
        return 1
    fi

    echo -n "$base"
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
    if ! bkp_path="$(get_tmp_file_name "${prefix}${base}" "true")"; then
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