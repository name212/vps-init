#!/usr/bin/env bash

set -Eeuo pipefail


export CONST_OUT_DIFF_OR_HAS_DIFF="true"
export CONST_DIFF_ADD_ARGS=("--color=always")

# shellcheck disable=SC2329
function out_diff() {
    local diff_str="${1:-}"
    local src_str="${2:-}"
    local dest_str="${3:-}"
    local title="${4:-Unknown}"
    local should_out_diff="${5:-"$CONST_OUT_DIFF_OR_HAS_DIFF"}"
    local has_diff=""

    local diff_to_out=""
    local diff_action=""
    local diff_action_msg=""

    if [ -n "$diff_str" ]; then
        diff_action="echo_warn"
        diff_action_msg="--- Changes: ---"
        diff_to_out="$diff_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -n "$src_str" ] && [ -z "$dest_str" ]; then
        diff_action="echo_info"
        diff_action_msg="--- Add new: ---"
        diff_to_out="$src_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -z "$src_str" ] && [ -n "$dest_str" ]; then
        diff_action="echo_error" 
        diff_action_msg="--- Remove old: ---"
        diff_to_out="$dest_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    else
        diff_action="echo_info"
        diff_action_msg="--- No diff ---"
    fi

    if [[ "$should_out_diff" == "$CONST_OUT_DIFF_OR_HAS_DIFF" ]]; then
        echo_info "--- Diff for: $title ---"
        "$diff_action" "$diff_action_msg"
        if [ -n "$diff_to_out" ]; then
            echo "$diff_to_out"
        fi
        echo_info "--- End diff for $title ---"
    fi


    if [[ "$has_diff" == "$CONST_OUT_DIFF_OR_HAS_DIFF" ]]; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function calc_diff_str() {
    local src="${1:-}"
    local dst="${2:-}"
    local title="${3:-Unknown}"

    local diff_out=""
    local diff_ret="0"

    # shellcheck disable=SC2090
    if diff_out="$(diff "${CONST_DIFF_ADD_ARGS[@]}" <(echo "$dst") <(echo "$src"))"; then
        diff_ret="0"
    else
        diff_ret="$?"
    fi

    out_diff "$diff_out" "" "" "$title"
    return "$diff_ret"
}

# shellcheck disable=SC2329
function files_has_not_diff() {
    local src="${1:-}"
    local dest="${2:-}"
    local title="${3:-Unknown}"
    local should_out="${4:-"$CONST_OUT_DIFF_OR_HAS_DIFF"}"

    title="'${title}' from file '$src' to '$dest'"

    if [ -z "$src" ]; then
        echo_error "Source file not passed"
        return 255
    fi

    if [ -z "$dest" ]; then
        echo_error "Dest file not passed"
        return 255
    fi

    local diff_out=""

     if [ -f "$src" ] && [ ! -f "$dest" ]; then
        local src_str=""
        if ! src_str="$(cat "$src")"; then
            echo_error "Cannot read source '$src'"
            return 255
        fi

        out_diff "$diff_out" "$src_str" "" "$title" "$should_out"
        return $?
    fi

    if [ ! -f "$src" ] && [ -f "$dest" ]; then
        local dest_str=""
        if ! dest_str="$(cat "$dest")"; then
            echo_error "Cannot read dest '$dest'"
            return 255
        fi

        out_diff "$diff_out" "" "$dest_str" "$title" "$should_out"
        return $?
    fi

    local ret_diff="0"

    # shellcheck disable=SC2090
    if diff_out="$(diff "${CONST_DIFF_ADD_ARGS[@]}" "$dest" "$src")"; then
        diff_out=""
    else
        ret_diff="$?"
    fi

    out_diff "$diff_out" "" "" "$title" "$should_out"

    return "$ret_diff"
}
