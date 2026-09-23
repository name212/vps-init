#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["docker"]="07"

# shellcheck disable=SC2329
function install_docker_via_apt() {
    local packages=(
        "docker-ce" 
        "docker-ce-cli" 
        "containerd.io" 
        "docker-buildx-plugin" 
        "docker-compose-plugin"
    )

    for a_pkg in "$@"; do
        if [ -n "$a_pkg" ]; then
            packages+=("$a_pkg")
        fi
    done

    if check_packages_installed "${packages[@]}"; then
        echo_green "Docker already installed!"
        return 0
    fi

    echo_green "Add Docker's official GPG key..."

    if ! install -m 0755 -d /etc/apt/keyrings; then
        echo_red "Keyrings not installed"
        return 0
    fi
   
    if ! download_url "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.asc"; then
        echo_red "GPG keys not downloaded"
        return 0
    fi

    if ! chmod a+r /etc/apt/keyrings/docker.asc; then
        echo_red "Cannot chmod GPG keys"
        return 1
    fi

    echo_green "Add the docker repository to apt sources..."

# shellcheck disable=SC1091
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(source /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    echo_green "Install docker packages..."

    if ! install_packages "${packages[@]}"; then
        echo_red "Docker not installed!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function install_docker_via_apk() {
    local packages=(
        "dockerd" 
        "docker" 
    )

    for a_pkg in "$@"; do
        if [ -n "$a_pkg" ]; then
            packages+=("$a_pkg")
        fi
    done

    if check_packages_installed "${packages[@]}"; then
        echo_green "Docker already installed!"
        return 0
    fi

    if ! install_packages "${packages[@]}"; then
        echo_red "Docker not installed!"
        return 1
    fi

    if ! service_enable_service "dockerd"; then
        echo_error "Cannot enable openssh"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_docker_run() {
    echo_green "Install docker..."

    local additional_packages_str=""
    if ! additional_packages_str="$(extract_argument "-docker-install-additional-packages" "DOCKER_ADDITIONAL_PACKAGES" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "Cannot parse additional packages"
        return 1
    fi

    local -a additional_pkgs=()
    if [ -n "$additional_packages_str" ]; then
        readarray -d ',' -t additional_pkgs <<<"$additional_packages_str"
    fi

    # shellcheck disable=SC2155
    # shellcheck disable=SC2034
    local pkg_manager="$(get_package_manager)"

    local install_fun=""

    if [[ "$pkg_manager" == "$SYS_PACKAGES_ENGINE_APT" ]]; then
        install_fun="install_docker_via_apt"
    elif [[ "$pkg_manager" == "$SYS_PACKAGES_ENGINE_APK" ]]; then
        install_fun="install_docker_via_apk"
    else
        echo_error "Incorrect package manager '$pkg_manager'"
        return 1
    fi

    if ! "$install_fun" "${additional_pkgs[@]}"; then
        echo_error "Docker is not installed via '$pkg_manager'!"
        return 1
    fi 

    echo_green "Docker installed!"
}

# shellcheck disable=SC2329
function phase_docker_help() {
    echo -n "
    Install docker
    Options
    --docker-install-additional-packages comma-separated-packages
        Install additional packages for docker (for example luci-app-dockerman for OpenWRT)
        Optional.
        Can be provided with env DOCKER_ADDITIONAL_PACKAGES
"
 }

# shellcheck disable=SC2329
function phase_docker_disable_env() {
    echo -n "DISABLE_DOCKER"
}