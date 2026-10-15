#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["install_additional_pkgs"]="08"

# shellcheck disable=SC2034
CONST_ADDITIONAL_PACKAGES_ARG="--install-additional-packages"
# shellcheck disable=SC2034
CONST_ADDITIONAL_PACKAGES_ENV="INSTALL_ADDITIONAL_PACKAGES"

# shellcheck disable=SC2329
function phase_install_additional_pkgs_run() {
    echo_info "Install additional packages..."

    local additional_packages_str=""
    if ! additional_packages_str="$(extract_value_argument_no_validate "$CONST_ADDITIONAL_PACKAGES_ARG" "$CONST_ADDITIONAL_PACKAGES_ENV" "$@")"; then
        echo_error "Cannot parse additional packages"
        return 1
    fi

    local -a __install_additional_pkgs=()

    if ! str_empty "$additional_packages_str"; then
        if ! split_by_comma "__install_additional_pkgs" "$additional_packages_str" "trim_spaces"; then
            echo_error "Cannot split additional packages str '$additional_packages_str' by comma"
            return 1
        fi
    fi

    if is_array_empty "__install_additional_pkgs"; then
        echo_info "Passed empty additional packages. Skip."
        return 0
    fi

    if ! install_packages "${__install_additional_pkgs[@]}"; then
        echo_error "Cannot install additional packages"
        return 1
    fi

    echo_info "Additional packages installed!"
}

# shellcheck disable=SC2329
function phase_install_additional_pkgs_help() {
    echo -n "
    Install additional packages
    Options:
    ${CONST_ADDITIONAL_PACKAGES_ARG} PACKAGES_LIST_STR
      Comma-separated list of packages to install.
      If not any passed packages will skip.
      Can be provided with env $CONST_ADDITIONAL_PACKAGES_ENV
"
}

# shellcheck disable=SC2329
function phase_install_additional_pkgs_disable_env() {
    echo -n "DISABLE_INSTALL_ADDITIONAL_PACKAGES"
}

