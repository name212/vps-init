#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function replace_file() {
    local src="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local remove_src="${4:-true}"
    local not_ask="${5:-false}"

    function __replace_file_remove_src() {
        local __src="${1:-}"
        local __remove_src="${2:-}"
        local __title="${3:-}"

        if ! str_eq "$__remove_src" "true"; then
            return 0
        fi

        echo_info "'$__title' delete source '$__src'"

        if ! rm -f "$__src"; then
            echo_warn "'$__title' source file '$__src' not deleted!"
            return 0
        fi

        return 0
    }

    local ret_diff="0"

    if files_has_not_diff "$src" "$dest" "$title" "$CONST_OUT_DIFF_OR_HAS_DIFF"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if num_eq "$ret_diff" "255"; then
        echo_error "Internal diff error. Source file '$src' not deleted"
        return 1
    fi

    if num_eq "$ret_diff" "0"; then
        echo_info "No diff."
        __replace_file_remove_src "$src" "$remove_src" "$title"
        return 0
    fi
    
    # prevent to break output
    sleep 1

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        echo_error "Disallow replace $dest"
        __replace_file_remove_src "$src" "$remove_src" "$title"
        return 1
    fi

    local perm=""
    local owner=""

    if is_file_path_exists "$dest"; then
         if ! perm="$(get_path_permission_mode "$dest")"; then
            echo_error "Cannot get dest '$dest' permissions for '$title'"
            return 1
        fi

        if ! owner="$(get_path_owner "$dest")"; then
            echo_error "Cannot get dest '$dest' owner for '$title'"
            return 1
        fi
    fi

    if ! cp "$src" "$dest"; then
        echo_error "'$title' not replaced. Source '$src' not deleted"
        return 1
    fi

    if ! str_empty "$perm"; then
        echo "'$title' dest file exists. Change permissions to '$perm' and owner to '$owner'"
        if ! set_path_perm_with_owner "$dest" "$perm" "$owner"; then
            echo_error "'$title' replaced, but cannot set owner and permissions for dest '$dest'. Source '$src' not deleted"
            return 1
        fi
    fi

    __replace_file_remove_src "$src" "$remove_src" "$title"

    return 0
}

# shellcheck disable=SC2329
function sync_file_content() {
    local content="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local not_ask="${4:-false}"

    if str_empty "$dest"; then
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
        echo_error "File for sync not passed for '$title'"
        return 255
    fi

    local temp_file=""

    if ! temp_file="$(temp_file_with_content "$content")"; then
        echo_error "Cannot create temp file for content for '$title'"
        return 255
    fi

    if files_has_not_diff "$temp_file" "$dest" "$title" "false"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if num_eq "$ret_diff" "255"; then
        echo_error "Internal diff error"
        if ! rm -f "$temp_file"; then
            echo_error "Cannot remove temp file for sync '$temp_file' for '$title'"
        fi
        return 255
    fi

    if num_eq "$ret_diff" "0"; then
        if ! rm -f "$temp_file"; then
            echo_warn "Cannot remove temp file for sync '$temp_file' for '$title'"
        fi
        return 0
    fi

    if ! replace_file "$temp_file" "$dest" "$title" "true" "$not_ask"; then
        echo_error "Cannot sync file '$dest' for '$title'"
        return 255
    fi

    return 1
}
