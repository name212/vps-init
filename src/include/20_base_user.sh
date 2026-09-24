#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_REMOVE_PASSWORD="true"
export CONST_SUDO_NO_PASS="true"

# shellcheck disable=SC2329
function update_passwd_for_user() {
    local name="$1"
    local remove_password="${2-false}"
    local password="${3-}"

     if [[ "$remove_password" == "$CONST_REMOVE_PASSWORD" ]]; then
        echo_info "Remove password for user ${name}..."
        if ! passwd -d "$name"; then
            echo_error "Password not removed for $name"
            return 1
        fi

        return 0
    fi

    if [ -z "$password" ]; then
        echo_info "Please set password for ${name}:"
        if ! passwd "${name}"; then
            echo_error "Password not set for $name"
            return 1
        fi

        return 0
    fi

    local enter_pass=""
    printf -v enter_pass "%s\n%s" "$password" "$password"

    if ! passwd "$name" <<<"$enter_pass"; then
        echo_error "Cannot update passed password for $name"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function get_passwd_str_for_user() {
    local user_name="${1:-}"

    local user_passwd=""
    if ! user_passwd="$(grep "^${user_name}:" "/etc/passwd")"; then
        return 1
    fi

    if [ -z "$user_passwd" ]; then
        return 1
    fi

    echo -n "$user_passwd"
    return 0
}

# shellcheck disable=SC2329
function get_user_home(){
    local name="$1"

    local user_passwd=""
    if ! user_passwd="$(get_passwd_str_for_user "$name")"; then
        echo_error "cannot get passwd ent for $name"
        return 1
    fi

    local user_home=""
    if ! user_home="$(cut -d: -f6 <<<"$user_passwd")"; then 
        echo_error "cannot extract home for $name"
        return 1
    fi

    if [ -z "$user_home" ]; then
        echo_error "User home not found for $name"
        return 1
    fi

    if [ ! -d "$user_home" ]; then
        echo_error "User home $user_home is not directory for $name"
        return 1
    fi

    echo -n "$user_home"
    return 0
}

# shellcheck disable=SC2329
function add_user() {
    local name="$1"
    local remove_password="${2-false}"
    local not_ask="${3-false}"
    local password="${4-}"

    if [ -z "$name" ]; then
        echo_error "User name is empty"
        return 1
    fi

    local user_exists="true"

    if ! get_passwd_str_for_user "$name" > /dev/null; then
        echo_info "Add user ${name}..."

        if ! useradd -m -s /bin/bash "$name"; then
            echo_error "User $name not added!"
            return 1
        fi

        user_exists="false"
    fi

    if [[ "$user_exists" == "true" ]]; then
        if ! ask_user "User $name exists. Update password?" "$not_ask"; then
            echo_warn "Skip update password for $name"
            echo_info "User ${name} updated!"
            return 0
        fi
    fi
    
    if ! update_passwd_for_user "$name" "$remove_password" "$password"; then 
        return 1
    fi

    echo_info "User ${name} added or updated!"
}

# shellcheck disable=SC2329
function get_group_str() {
    local group_name="$1"
    local res_str=""

    if ! res_str="$(grep "^${group_name}:" /etc/group)"; then
        return 1
    fi

    if [ -z "$res_str" ]; then
        return 1
    fi

    echo -n "$res_str"
    return 0
}

# shellcheck disable=SC2329
function add_user_to_group() {
    local user_name="$1"
    local group_name="$2"

    if get_group_str "$group_name" | grep -q "\b$user_name\b"; then
        echo_info "User $user_name already in group $group_name"
        return 0
    fi

    echo_info "Add user $user_name to group ${group_name}..."

    if ! usermod -aG "$group_name" "$user_name"; then
        echo_error "Cannot add user $user_name to group ${group_name}!"
        return 1
    fi

    echo_info "User $user_name added to group ${group_name}!"
}

# shellcheck disable=SC2329
function add_user_to_sudoers() {
    local name="$1"
    local no_password="${2-no}"
    local not_ask="${3-no}"

    if [ -z "$name" ]; then
        echo_error "user name did not pass"
        return 1
    fi

    local sudoers_str="$name    ALL=(ALL:ALL) ALL"
    if [[ "$no_password" == "$CONST_SUDO_NO_PASS" ]]; then
        sudoers_str="$name    ALL=(ALL) NOPASSWD: ALL"
    fi

    local sudoers_path="/etc/sudoers"

    if grep -q "$sudoers_str" "$sudoers_path"; then
        echo_info "User $name already add to $sudoers_path"
        return 0
    fi

    # shellcheck disable=SC2155
    local tmp_file="$(mktemp)"

    if ! cp "$sudoers_path" "$tmp_file"; then
        delete_file "$tmp_file" || true
        echo_error "Cannot copy $sudoers_path to $tmp_file for check for user $name"
        return 1
    fi

    if [ ! -s  "$tmp_file" ]; then
        delete_file "$tmp_file" || true
        echo_error "$tmp_file is empty after copy sudoers for user $name"
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
        echo_error "$tmp_file  sudoers for user $name is invalid. Tmp file not deleted"
        return 1
    fi

    if ! replace_file "$tmp_file" "$sudoers_path" "Add sudo for user $name" "true" "$not_ask"; then
        return 1
    fi

    return 0
 }

# shellcheck disable=SC2329
function add_pubkey_for_user() { 
    local name="$1"
    local ssh_key_file="$2"
    local not_ask="${3-no}"

    if [ -z "$name" ]; then
        echo_error "user name did not pass"
        return 1
    fi

    local ssh_key=""

    if [ -n "$ssh_key_file" ]; then
         if [ -f "$ssh_key_file" ]; then
            if ! ssh_key="$(cat "$ssh_key_file")"; then
                echo_warn "$ssh_key_file is not file. Skip add ssh pub key for $name"
                return 0
            fi
        else
            ssh_key="$ssh_key_file"
        fi
    fi
   
    if [ -z "$ssh_key" ]; then
        echo_warn "$ssh_key_file is empty. Skip add ssh pub key for $name"
        return 0
    fi

    local user_home=""
    if ! user_home="$(get_user_home "$name")"; then 
        echo_error "$user_home"
        return 1
    fi 

    local ssh_dir="${user_home}/.ssh"

    if ! mkdir -p "$ssh_dir"; then
        echo_error "cannot create $ssh_dir dir for $name"
        return 1
    fi

    if ! chmod 700 "$ssh_dir"; then
        echo_error "cannot chmod $ssh_dir dir for $name"
        return 1
    fi

    if ! chown "${name}:${name}" "$ssh_dir"; then
        echo_error "cannot chown $ssh_dir dir for $name"
        return 1
    fi

    local auth_keys_file="${ssh_dir}/authorized_keys"

    # shellcheck disable=SC2155
    local tmp_file="$(mktemp)"

    if [ -f "$auth_keys_file" ]; then
        if ! cp "$auth_keys_file" "$tmp_file"; then
            delete_file "$tmp_file" || true
            echo_error "cannot copy $auth_keys_file to $tmp_file for add key for $name"
            return 1
        fi
        echo "" >> "$tmp_file"
    fi

    {
        echo "$ssh_key"
        echo ""
    } >> "$tmp_file"

    if ! replace_file "$tmp_file" "$auth_keys_file" "Add public key from $ssh_key_file for $name" "true" "$not_ask"; then
        return 1
    fi

    if ! chmod 600 "$auth_keys_file"; then
        echo_error "cannot chmod $auth_keys_file file for $name"
        return 1
    fi

    if ! chown "${name}:${name}" "$auth_keys_file"; then
        echo_error "cannot chown $auth_keys_file file for $name"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function get_loginable_users() {
    local passwd_out=""
    if ! passwd_out="$(cat /etc/passwd)"; then
        echo_error "Failed to cat /etc/passwd for getting loginable users"
        return 1
    fi

    local users_passwd_list=""
    if ! users_passwd_list="$(grep -E -v '(false|nologin)$' <<<"$passwd_out")"; then
        echo -n ""
        return 0
    fi

    local users_raw_list=""
    if ! users_raw_list="$(cut -d: -f1 <<<"$users_passwd_list")"; then
        echo_error "Failed to extract users names loginable users"
        return 1
    fi


    local -a users_list=()
    IFS=$'\n' read -rd '' -a users_list <<< "$users_raw_list"

    local -a prepared_users=()

    for uu in "${users_list[@]}"; do
        if [ -z "$uu" ]; then
            continue
        fi
        prepared_users+=("$uu")
    done

    # shellcheck disable=SC2155
    local res="$(IFS=":"; echo "${prepared_users[*]}")"

    echo -n "$res"
    return 0
}