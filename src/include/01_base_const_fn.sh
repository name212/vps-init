#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_NEW_LINE=$'\n'

# shellcheck disable=SC2034
export CONST_NO_VALIDATE="no_validate"

# shellcheck disable=SC2329
function __rand_str_n() {
    local num=${1:-1}

	local str=""
    if ! str="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$num")"; then
        true
    fi

    echo -n "$str"
    return 0
}

# shellcheck disable=SC2329
function __escape_new_line() {
	local val="${1:-}"
	echo -n "${val//${CONST_NEW_LINE}/\\n}"
	return 0
}
