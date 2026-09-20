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
    local has_diff=""

    echo_green "--- Diff for: $title ---"

    if [ -n "$diff_str" ]; then
        echo_yellow "--- Changes: ---"
        echo "$diff_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -n "$src_str" ] && [ -z "$dest_str" ]; then
        echo_green "--- Add new: ---"
        echo "$src_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -z "$src_str" ] && [ -n "$dest_str" ]; then
        echo_red "--- Remove old: ---"
        echo "$dest_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    else
        echo_green "--- No diff ---"
    fi

    echo_green "--- End diff for $title ---"

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
function files_has_diff() {
    local src="${1:-}"
    local dest="${2:-}"
    local title="${3:-Unknown}"

    title="'${title}' from file '$src' to '$dest'"

    if [ -z "$src" ]; then
        echo_red "Source file not passed"
        return 255
    fi

    if [ -z "$dest" ]; then
        echo_red "Dest file not passed"
        return 255
    fi

    local diff_out=""

     if [ -f "$src" ] && [ ! -f "$dest" ]; then
        local src_str=""
        if ! src_str="$(cat "$src")"; then
            echo_red "Cannot read source '$src'"
            return 255
        fi

        out_diff "$diff_out" "$src_str" "" "$title"
        return $?
    fi

    if [ ! -f "$src" ] && [ -f "$dest" ]; then
        local dest_str=""
        if ! dest_str="$(cat "$dest")"; then
            echo_red "Cannot read dest '$dest'"
            return 255
        fi

        out_diff "$diff_out" "" "$dest_str" "$title"
        return $?
    fi

    local ret_diff="0"

    # shellcheck disable=SC2090
    if diff_out="$(diff "${CONST_DIFF_ADD_ARGS[@]}" "$dest" "$src")"; then
        diff_out=""
    else
        ret_diff="$?"
    fi

    out_diff "$diff_out" "" "" "$title"

    return $ret_diff
}
