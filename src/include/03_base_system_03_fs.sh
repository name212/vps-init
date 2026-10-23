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

    if files_has_not_diff "$src" "$dest" "$title" "$CONST_OUT_DIFF_OR_HAS_DIFF"; then
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
function check_file_is_not_empty() {
    local val="$1"

    local real=""

    if ! real="$(realpath "$val")"; then
        echo_error "Cannot extract real path for '$val'"
        return 1
    fi

    if [ ! -f "$real" ]; then
        echo_error "'$val' is not file!"
        return 1
    fi

    if [ ! -s "$real" ]; then
        echo_error "'$val' is empty file!"
        return 1
    fi

    echo -n "$real"
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
