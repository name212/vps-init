#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["users"]="04"

# shellcheck disable=SC2329
function users_validate_pub_key() {
    local ssh_key="${1-}"

    if [ -z "$ssh_key" ]; then
        return 0
    fi

    if [[ "$ssh_key" == ssh-rsa* ]]; then
        echo_info "found rsa key string"
        return 0
    fi

    if [ ! -s "$ssh_key" ]; then
        echo -n "'$ssh_key' is not file not start string 'ssh-rsa' (rsa pub-key)"
        return 1
    fi

    if [[ "$ssh_key" == *.pub ]]; then
        echo_info "found pub key file '$ssh_key'"
        return 0
    fi

    local base=""
    if base="$(basename "$ssh_key")"; then
        if [[ "$base" != "authorized_keys" ]]; then
            echo -n "'$ssh_key' is not authorized_keys"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_users_run() {
    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_info "Add users..."

    local -A users=()
    local -A users_no_pass=()
    local -A users_passwords=()
    local -A users_sudo=()
    local -A users_sudo_no_pass=()
    local -A users_keys=()

    if ! users_extract_configuration "users" "users_no_pass" "users_passwords" "users_sudo" "users_sudo_no_pass" "users_keys" "$@"; then
        echo_error "Cannot extract users"
        return 1
    fi

    if [[ "${#users[@]}" == "0" ]]; then
        echo_info "Not found users to add. Skip"
        return 0
    fi

    local has_invalid_keys=""
    for key_user in "${!users_keys[@]}"; do
        local key="${users_keys["$key_user"]}"
        echo_info "Verify key '$key' for user $key_user"
        local err_ssh_key=""
        if ! err_ssh_key="$(users_validate_pub_key "$key")"; then
            echo_error "ssh pub key file $key for user $key_user invalid: $err_ssh_key"
            has_invalid_keys="true"
        fi
    done

    if [[ "$has_invalid_keys" == "true" ]]; then
        echo_error "^^^ Has invalid ssh pub keys"
        return 1
    fi

    for add_user in "${!users[@]}"; do
        echo_info "Try to add user $add_user ..."

        local user_no_pass="${users_no_pass["$add_user"]}"
        local user_pass="${users_passwords["$add_user"]}"
        local user_should_sudo="${users_sudo["$add_user"]}"
        local user_sudo_no_pass="${users_sudo_no_pass["$add_user"]}"
        local user_ssh_key="${users_keys["$add_user"]}"

        if ! add_user "$add_user" "$user_no_pass" "$not_ask" "$user_pass"; then
            return 1
        fi

        if [[ "$user_should_sudo" == "$CONST_SHOULD_SUDO" ]]; then
            echo_info "Add user $add_user to sudo group..."
            if ! add_user_to_group "$add_user" "sudo"; then
                return 1
            fi

            echo_info "Add user $add_user to sudoers..."
            if ! add_user_to_sudoers "$add_user" "$user_sudo_no_pass" "$not_ask"; then
                return 1
            fi
        fi

        if [ -n "$user_ssh_key" ]; then
            echo_info "Add public keys for $add_user from $user_ssh_key ..."
            if ! add_pubkey_for_user "$add_user" "$user_ssh_key" "$not_ask"; then
                return 1
            fi
        fi

        echo_info "User $add_user added!"
    done
}

# shellcheck disable=SC2329
function phase_users_help() {
    users_configuration_help
}

# shellcheck disable=SC2329
function phase_users_disable_env() {
    echo -n "DISABLE_USERS"
}