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
function is_path_exists() {
    local path="$1"

    if [ -e "$path" ]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function is_file_path_exists() {
    local path="$1"

    if [ -f "$path" ]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function is_dir_path_exists() {
    local path="$1"

    if [ -d "$path" ]; then
        return 0
    fi

    return 1
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
