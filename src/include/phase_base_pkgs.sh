#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["base_pkgs"]="01"


function phase_base_pkgs_run() {
    echo_green "Install base packages..."

    local packages=(
        "bash-completion" 
        "ca-certificates" 
        "nano" 
        "vim" 
        "less" 
        "dnsutils" 
        "iputils-ping" 
        "htop" 
        "mc" 
        "curl" 
        "jq" 
        "yq"
        "libc-bin"
        "diffutils"
        # "git"
        "procps"
    )

    if check_packages_installed "${packages[@]}"; then
        echo_green "Base packages already installed!"
        return 0
    fi
    
    if ! install_packages "${packages[@]}"; then
        echo_red "Base packages not installed!"
        return 1
    fi

    echo_green "Base packages installed!"
}

function phase_base_pkgs_help() {
    echo "Install base packages
  No options.
"
}

function phase_base_pkgs_disable_env() {
    echo -n ""
}