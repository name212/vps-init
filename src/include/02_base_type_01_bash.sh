#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function is_function_declared() {
    local fun="${1:-}"

    if [ -z "$fun" ]; then
        echo_error "Function is not passed"
        return 1
    fi

    if ! declare -F "$fun" > /dev/null; then
        echo_error "Function '$fun' is not declared"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function is_array_var() {
    local var_name="$1"

    local declare_out=""
    if declare_out="$(declare -p -- "$var_name" 2>&1)"; then
        if [[ "$declare_out" == "declare -a "* ]]; then 
            return 0
        fi
    fi

    return 1
}

# shellcheck disable=SC2329
function is_dict_var() {
    local var_name="$1"

    local declare_out=""
    if declare_out="$(declare -p -- "$var_name" 2>&1)"; then
        if [[ "$declare_out" == "declare -A "* ]]; then 
            return 0
        fi
    fi
    
    return 1
}

# shellcheck disable=SC2329
function is_array_or_dict_var() {
    local var_name="$1"

    if is_array_var "$var_name"; then
        return 0
    elif is_dict_var "$var_name"; then
        return 0
    fi

    return 1
}
