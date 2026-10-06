#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_SCRIPT_NAME="$0"

# shellcheck disable=SC2034
export CONST_SCRIPT_NAME_FULL="$CONST_SCRIPT_NAME"
if ! CONST_SCRIPT_NAME_FULL="$(realpath "$CONST_SCRIPT_NAME")"; then
    CONST_SCRIPT_NAME_FULL="$CONST_SCRIPT_NAME"
fi

# shellcheck disable=SC2155
export WORKING_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck disable=SC2034
export CONST_NEW_LINE=$'\n'


# shellcheck disable=SC2034
export CONST_FAIL_MAIN_EXIT_CODE_PREFIX="Main returns exit code:"

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

function get_original_script_name() {
    if [ -n "${SCRIPT_ORIGINAL_PATH:-}" ]; then
        echo -n "$SCRIPT_ORIGINAL_PATH"
        return 0
    fi

    if [ -n "${CONST_SCRIPT_NAME:-}" ]; then
        echo -n "$CONST_SCRIPT_NAME"
        return 0
    fi

    echo -n "unknown-name-script.sh"

    return 0
}
