#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["docker"]="03"

# shellcheck disable=SC2329
function phase_docker_run() {
    if [[ "${DISABLE_DOCKER-no}" == "true" ]]; then
        echo_yellow "Skip install docker!"
        return 0
    fi
    
    echo_green "Install docker..."

    local packages=(
        "docker-ce" 
        "docker-ce-cli" 
        "containerd.io" 
        "docker-buildx-plugin" 
        "docker-compose-plugin"
    )

    if check_packages_installed "${packages[@]}"; then
        echo_green "Docker already installed!"
        return 0
    fi

    echo_green "Add Docker's official GPG key..."

    install -m 0755 -d /etc/apt/keyrings
    download_url "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.asc"
    chmod a+r /etc/apt/keyrings/docker.asc

    echo_green "Add the docker repository to apt sources..."

    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(source /etc/os-release && echo_green "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    echo_green "Install docker packages..."

    if ! install_packages "${packages[@]}"; then
        echo_red "Docker not installed!"
        return 1
    fi

    echo_green "Docker installed!"
}

# shellcheck disable=SC2329
function phase_docker_help() {
    echo -n "
    Install docker
    No options. 
"
 }

# shellcheck disable=SC2329
function phase_docker_disable_env() {
    echo -n "DISABLE_DOCKER"
}