#!/usr/bin/env bash

set -Eeuo pipefail

function run_passwd_for_user() {
    local name="$1"
    local password="${2-}"

    if [ -z "$password" ]; then
        echo_green "Please set password for ${name}:"
        if ! passwd "${name}"; then
            echo_red "Password not set for $name"
            return 1
        fi

        return 0
    fi

    local enter_pass=""
    printf -v enter_pass "%s\n%s" "$password" "$password"

    if ! passwd username <<<"$enter_pass"; then
        echo_red "Cannot use not interactive $name"
        return 1
    fi

    return 0
}

function add_user() {
    local name="$1"
    local remove_password="${2-false}"
    local password="${3-}"

    if [ -z "$user" ]; then
        echo_red "User name is empty"
        return 1
    fi

    if ! getent passwd "$name" > /dev/null; then
        echo_green "Add user ${name}..."

        if ! useradd -m -s /bin/bash "$name"; then
            echo_red "User $name not added!"
            return 1
        fi
    else
        echo_green "User '$name' exists. Update password..."
    fi


    if [[ "$remove_password" == "true" ]]; then
        echo_green "Remove password for user ${name}..."
        if ! passwd -d "$name"; then
            echo_red "Password not removed for $name"
            return 1
        fi
    else
        if ! run_passwd_for_user "$name" "$password"; then 
            return 1
        fi
    fi

    echo_green "User ${name} added or updated!"
}

function add_user_to_group() {
    local user_name="$1"
    local group_name="$2"

    if getent group "$group_name" | grep -q "\b$user_name\b"; then
        echo_green "User $user_name already in group $group_name"
        return 0
    fi

    echo_green "Add user $user_name to group ${group_name}..."

    if ! usermod -aG "$group_name" "$user_name"; then
        echo_red "Cannot add user $user_name to group ${group_name}!"
        return 1
    fi

    echo_green "User $user_name added to group ${group_name}!"
}

function add_user_to_sudoers() {
    local name="$1"
    local not_ask="${2-no}"

    if [ -z "$name" ]; then
        echo_red "user name did not pass"
        return 1
    fi

    local sudoers_str="$name    ALL=(ALL:ALL) ALL"

    local sudoers_path="/etc/sudoers"

    if grep "$sudoers_str" "$sudoers_path"; then
        echo_green "User $name already add to $sudoers_path"
        return 0
    fi

    # shellcheck disable=SC2155
    local tmp_file="$(mktemp)"

    if ! cp "$sudoers_path" "$tmp_file"; then
        delete_file "$tmp_file" || true
        echo_red "Cannot copy $sudoers_path to $tmp_file for check for user $name"
        return 1
    fi

    if [ ! -s  "$tmp_file" ]; then
        delete_file "$tmp_file" || true
        echo_red "$tmp_file is empty after copy sudoers for user $name"
        return 1
    fi

    {
    echo ""
    echo "# Add sudo for user $name"
    echo ""
    echo "$sudoers_str"
    echo ""
    } >> "$tmp_file"

    if ! visudo -q -c -f "$tmp_file"; then
        echo_red "$tmp_file  sudoers for user $name is invalid. Tmp file not deleted"
        return 1
    fi

    echo_green "--- New sudoers from $tmp_file ---"
    cat "$tmp_file"
    echo_green "--- End file ---"

    if ! ask_user "You can replace $sudoers_path with $tmp_file ?" "$not_ask"; then
        delete_file "$tmp_file" || true
        echo_red "Disallow replace $sudoers_path"
        return 1
    fi

    if ! cp "$tmp_file" "$sudoers_path"; then
        echo_red "sudoers not replaced for $name . Tmp file $tmp_file not deleted"
        return 1
    fi

    return 0
 }

 function add_pubkey_for_user() { 
    local name="$1"
    local ssh_key_file="$2"
    local not_ask="${2-no}"

    if [ -z "$name" ]; then
        echo_red "user name did not pass"
        return 1
    fi

    if [ ! -f "$ssh_key_file" ]; then
        echo_yellow "$ssh_key_file is not file. Skip add ssh pub key for $name"
        return 0
    fi

    # shellcheck disable=SC2155
    local ssh_key="$(cat "$ssh_key_file")"

    if [ -z "$ssh_key" ]; then
        echo_yellow "$ssh_key_file is empty. Skip add ssh pub key for $name"
        return 0
    fi

    local user_passwd=""
    if ! user_passwd="$(getent passwd "$name")"; then
        echo_red "cannot get passwd ent for $name"
        return 1
    fi

    local user_home=""
    if ! user_home="$(cut -d: -f6 <<<"$user_passwd")"; then 
        echo_red "cannot extract home for $name"
        return 1
    fi
 }