#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_NOT_ASK_ARG="--not-ask"
# shellcheck disable=SC2034
export CONST_NOT_ASK_ENV="NOT_ASK"

# shellcheck disable=SC2329
function parse_not_ask() {
    if arg_flag_is_set "$CONST_NOT_ASK_ARG" "$CONST_NOT_ASK_ENV" "$@"; then
        echo -n "$CONST_NOT_ASK_VAL"
        return 0
    fi

    echo "$CONST_ASK_VAL"
    return 0
}

# shellcheck disable=SC2329
function not_ask_help() {
    echo -n "
    ${CONST_NOT_ASK_ARG}
      If passed will not ask user about actions.
      Env ${CONST_NOT_ASK_ENV}=true for set."
}
