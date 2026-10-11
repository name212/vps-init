#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function is_dict_has_len() {
    local var_name="$1"
    local should_len="$2"

    __is_array_dict_has_len "is_dict_var" "$should_len" "$var_name"
    return $?
}

# shellcheck disable=SC2329
function is_dict_empty() {
    local var_name="$1"

    is_dict_has_len "$var_name" "0"
    return $?
}

# shellcheck disable=SC2329
function is_dict_has_key() {
    local var_name="$1"
    local key="$2"

    if ! is_dict_var "$var_name"; then
        echo_error "Variable '$var_name' is not dict"
        return 255
    fi

    local -n is_dict_has_key_dict="$var_name"

    if [[ -v is_dict_has_key_dict["$key"] ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function dict_get_key() {
    local var_name="$1"
    local key="$2"

    if ! is_dict_has_key "$var_name" "$key"; then
        return 1
    fi

    local -n dict_get_key_dict="$var_name"

    echo -n "${dict_get_key_dict[$key]}"

    return 0
}