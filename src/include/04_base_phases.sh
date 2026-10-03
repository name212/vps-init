#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
declare -A PHASES_WITH_INDEX=()
# shellcheck disable=SC2034
declare -a COMMANDS_LIST=()

# shellcheck disable=SC2034
export CONST_PHASES_REORDER_FUN_NAME="global_reorder_phase"

# shellcheck disable=SC2329
function phase_get_disable_env() {
    local phase="$1"

    local env_name=""

    local env_fun="phase_${phase}_disable_env"
    if is_function_declared "$env_fun"; then
        env_name="$("$env_fun")"
    fi

    echo -n "$env_name"
}

# shellcheck disable=SC2329
function phase_run_func() {
    local phase="$1"

    local phase_func="phase_${phase}_run"

    if ! is_function_declared "$phase_func"; then
        echo_error "Internal error: '$phase_func' func not declared for phase '$phase'!"
        return 1
    fi

    echo -n "$phase_func"
    return 0
}

# shellcheck disable=SC2329
function phase_change_order() {
    local phase="$1"
    local cur_order="$2"

    local reorder_func="$CONST_PHASES_REORDER_FUN_NAME"

    if ! is_function_declared "$reorder_func" &> /dev/null; then
        echo -n "$cur_order"
        return 0
    fi

    local new_order=""
    if ! new_order="$("$reorder_func" "$phase" "$cur_order")"; then
        echo_error "Cannot call '$reorder_func' to get order for phase '$phase'"
        return 1
    fi

    if [ -z "$new_order" ]; then
        echo_error "'$reorder_func' returned empty order for phase '$phase'"
        return 1
    fi

    echo -n "$new_order"
    return 0
}

# shellcheck disable=SC2329
function phase_print_disable_help() {
    local phase="$1"

    # shellcheck disable=SC2155
    local env_name="$(phase_get_disable_env "$phase")"

    if [ -n "$env_name" ]; then
        echo "Can be disabled with set env ${env_name}=true"
        return 0
    fi

    echo "This phase is required and not be disabled!"
}

# shellcheck disable=SC2329
function phase_is_not_disabled() {
    local phase="$1"

     # shellcheck disable=SC2155
    local env_name="$(phase_get_disable_env "$phase")"

    if [ -z "$env_name" ]; then
        return 0
    fi

    if [ -v "$env_name" ]; then
        if [[ "${!env_name:-}" == "$CONST_FLAG_SET" ]]; then
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function run_passed_command() {
    local cmd_name="${1-}"
    
    local found=""
    for cmd in "${COMMANDS_LIST[@]}"; do
        if [[ "$cmd_name" == "$cmd" ]]; then
            found="true"
            break
        fi
    done

    if [[ "$found" != "true" ]]; then
        echo_error "Command '$cmd_name' not found!"
        return 1
    fi

    local run_func="cmd_${cmd_name}_run"

    if ! declare -F "$run_func" > /dev/null; then
        echo_error "Run function $run_func for command $cmd_name not found!"
        return 1
    fi

    shift

    if ! "$run_func" "$@"; then
        echo_error "Command $cmd_name failed" 
        return 1
    fi

    return 0
}