#!/usr/bin/env bash

set -Eeuo pipefail

if [ -z "${SYS_PACKAGES_ENGINE:-}" ]; then
    export SYS_PACKAGES_ENGINE="apt"
fi

# shellcheck disable=SC2329
function apt_update() {
    if ! apt update; then 
        echo_red "Cannot run apt update!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apt_install() {
    if ! apt install -y "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apt_search() {
    if dpkg-query -s "$1" &> /dev/null; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function apt_remove() {
    if ! apt purge -y --auto-remove "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_update() {
    if ! apk update; then 
        echo_red "Cannot run apk update!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_install() {
    if ! apk add --no-cache "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_search() {
    if apk info -e "$1" &> /dev/null; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function apk_remove() {
    if ! apk del "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function get_package_cmd() {
    local cmd_name="$1"
    case "$SYS_PACKAGES_ENGINE" in
        "apt")
            true
        ;;

        "apk")
            true
        ;;

        *)
            echo_red "SYS_PACKAGES_ENGINE '${SYS_PACKAGES_ENGINE}' incorrect"
            return 1
        ;;
    esac

    local res="${SYS_PACKAGES_ENGINE}_${cmd_name}"

    if ! declare -F "$res" > /dev/null; then
        echo_red "Internal error: '$res' func not declared!"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function install_packages() {
    echo_green "Install apt packages $* ..."

    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    local install_fun=""
    if ! install_fun="$(get_package_cmd install)"; then
        return 1
    fi

    if ! "$update_fun"; then 
        echo_red "Cannot run update indexes!"
        return 1
    fi

    if ! "$install_fun" "$@"; then
        echo_red "Cannot run apt install!"
        return 1
    fi

    echo_green "Packages $* installed!"
}

# shellcheck disable=SC2329
function check_packages_installed() {
    local search_fun=""
    if ! search_fun="$(get_package_cmd search)"; then
        return 1
    fi

    local all="true"
    while [[ $# -gt 0 ]]; do
        local name="$1"
        if ! "$search_fun" "$name"; then
            echo_green "$name not installed..."
            all="false"
        fi
        shift
    done

    if [[ "$all" == "false" ]]; then
        return 1
    fi
    
    return 0
}

# shellcheck disable=SC2329
function remove_packages() {
    local search_fun=""
    if ! search_fun="$(get_package_cmd search)"; then
        return 1
    fi

    local remove_fun=""
    if ! remove_fun="$(get_package_cmd remove)"; then
        return 1
    fi

    local -a for_remove=()

    while [[ $# -gt 0 ]]; do
        local name="$1"
        if "$search_fun" "$name"; then
            for_remove+=("$name")
        fi
        shift
    done

    if [[ "${#for_remove[@]}" == "0" ]]; then
        echo_green "All passed packages already removed"
        return 0
    fi

    echo_green "Remove packages ${for_remove[*]}"
    
    if ! "$remove_fun" "${for_remove[@]}"; then
        echo_red "Some packages not removed!"
        return 1
    fi

    return 0
}