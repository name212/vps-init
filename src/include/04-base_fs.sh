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
    local title="${3-No title}"
    local remove_src="${4-true}"
    local not_ask="${5-false}"

    if [ -z "$src" ]; then
        echo_red "Source file not passed"
        return 1
    fi

    if [ ! -f "$src" ]; then
        echo_red "Source file $src is not file"
        return 1
    fi

    if [ -z "$dest" ]; then
        echo_red "Dest file not passed"
        return 1
    fi

    echo_green "--- $title from $src ---"
    cat "$src"
    echo_green "--- End file ---"
    echo ""
    
    echo_green "--- Diff ---"
    if [ ! -f "$dest" ]; then
        echo_green "Add new file with content:"
        cat "$src"
    else
        diff "$src" "$dest" || true
    fi

    echo_green "--- End diff ---"
    
    # prevent to breack output
    sleep 1

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        echo_green "$title delete source $src"
        if ! rm "$src"; then
            echo_yellow "$title source file $src not deleted!"
            return 0
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
