#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_SCRIPT_NAME="$0"
# shellcheck disable=SC2034
export CONST_LIB_FILE_NAME="init-lib.sh"

# shellcheck disable=SC2034
export CONST_IDEMPOTENT_START_COMMENT="# start idempotent run"
# shellcheck disable=SC2034
export CONST_IDEMPOTENT_END_COMMENT="# end idempotent run"
# shellcheck disable=SC2034
export CONST_IDEMPOTENT_START_COMMENT="# start idempotent run"

# shellcheck disable=SC2155
export WORKING_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck disable=SC2034
declare -A PHASES_WITH_INDEX=()
# shellcheck disable=SC2034
declare -a COMMANDS_LIST=()

# shellcheck disable=SC2034
export CONST_NEW_LINE=$'\n'
# shellcheck disable=SC2034
export CONST_FAIL_MAIN_EXIT_CODE_PREFIX="Main returns exit code:"

# shellcheck disable=SC2034
export CONST_NO_VALIDATE="__no_validate"

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

