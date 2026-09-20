#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function delete_file() {
    if ! rm "$1"; then
        echo_red "$1 not deleted!"
        return 1
    fi

    echo_green "$1 deleted"
}

# shellcheck disable=SC2329
function replace_file() {
    local src="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local remove_src="${4:-true}"
    local not_ask="${5:-false}"

    local ret_diff="0"

    if files_has_not_diff "$src" "$dest" "$title" "$CONST_OUT_DIFF_OR_HAS_DIFF"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if [[ "$ret_diff" == "255" ]]; then
        echo_red "Internal diff error"
        return 1
    fi

    if [[ "$ret_diff" == "0" ]]; then
        echo_green "No diff. Skip"
        return 0
    fi
    
    # prevent to break output
    sleep 1

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        if [[ "$remove_src" == "true" ]]; then
            echo_green "$title delete source $src"
            if ! rm "$src"; then
                echo_yellow "$title source file $src not deleted!"
            fi
        fi
        echo_red "Disallow replace $dest"
        return 1
    fi

    if ! cp "$src" "$dest"; then
        echo_red "$title not replaced. Source $src not deleted"
        return 1
    fi

    if [[ "$remove_src" == "true" ]]; then
        echo_green "$title delete source $src"
        if ! rm "$src"; then
            echo_yellow "$title source file $src not deleted!"
            return 0
        fi
    fi

    return 0
}
