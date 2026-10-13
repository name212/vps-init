#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["base_pkgs"]="02"

# shellcheck disable=SC2329
function phase_base_pkgs_run() {
    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    if ! "$update_fun"; then
        echo_error "Cannot run update"
        return 1
    fi

    echo_info "Install base packages..."

    local packages=(
        "bash-completion" 
        "ca-certificates" 
        "nano" 
        "vim" 
        "less" 
        "dnsutils"
        "bind9-dnsutils"
        "iputils-ping" 
        "htop" 
        "mc" 
        "curl" 
        "jq" 
        "yq"
        "libc-bin"
        "diffutils"
        "git"
        "procps"
        "tzdata"
        "gnupg"
        "apt-transport-https"
        "chrony"
    )

    if check_packages_installed "${packages[@]}"; then
        echo_info "Base packages already installed!"
        return 0
    fi
    
    if ! install_packages "${packages[@]}"; then
        echo_error "Base packages not installed!"
        return 1
    fi

    echo_info "Base packages installed!"
}

# shellcheck disable=SC2329
function phase_base_pkgs_help() {
    echo -n "
    Install base packages
    No options.
"
}

# shellcheck disable=SC2329
function phase_base_pkgs_disable_env() {
    echo -n ""
}