#!/usr/bin/env bash

set -Eeuo pipefail

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
    if ! out="$(stat  --format "$format" "$path")"; then
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