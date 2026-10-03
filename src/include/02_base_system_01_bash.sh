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
function get_env_value_or_default() {
    local var_name="$1"
    local default_val="${2-}"

    if ! [[ -v "$var_name" ]]; then
        echo -n "$default_val"
        return 0
    fi

    echo -n "${!var_name}"
    return 0
}


# shellcheck disable=SC2329
function write_shebang_header() {
	local des_file="${1}"

    # bash not correct handle shebang and set 
    # when write file! 
	{
        echo -n "#"
        echo '!/usr/bin/env bash'
        echo -n 'se'
        echo 't -Eeuo pipefail'
    } > "$des_file"
}
