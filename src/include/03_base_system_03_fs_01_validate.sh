#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
CONST_PRIVATE_USERNAME_GROUP_NAME_RE="[a-z][a-z0-9-]{0,30}"

# shellcheck disable=SC2329
function check_is_permission_oct_valid() {
    local perm="$1"

    local perm_nums="01234567"
    local perm_re="^[$perm_nums]{3}[$perm_nums]?\$"
    if ! [[ "$perm" =~ $perm_re ]]; then
        echo_error "Permission number '$perm' is incorrect. Should match '$perm_re'"
        return 1
    fi

    echo -n "$perm"
    return 0
}

# shellcheck disable=SC2329
function check_is_username_valid() {
    local name="$1"

    local name_re="^${CONST_PRIVATE_USERNAME_GROUP_NAME_RE}\$"
    if ! [[ "$name" =~ $name_re ]]; then
        echo_error "Username or group '$name' is incorrect. Should match '$name_re'"
        return 1
    fi

    echo -n "$name"
    return 0
}


# shellcheck disable=SC2329
function check_is_chown_str_valid() {
    local str="$1"

    local num_re="^[0-9]+(:[0-9]+)?\$"

    if [[ "$str" =~ $num_re ]]; then
        echo -n "$str"
        return 0
    fi

    local name_re="^${CONST_PRIVATE_USERNAME_GROUP_NAME_RE}(:${CONST_PRIVATE_USERNAME_GROUP_NAME_RE})?\$"

    local name_re="^${CONST_PRIVATE_USERNAME_GROUP_NAME_RE}\$"
    if ! [[ "$str" =~ $name_re ]]; then
        echo_error "Chown string '$str' is incorrect. Should match '$name_re' or '$num_re'"
        return 1
    fi

    echo -n "$str"
    return 0
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