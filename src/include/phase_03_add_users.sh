#!/usr/bin/env bash

set -Eeuo pipefail

export CONST_SHOULD_SUDO="true"

# shellcheck disable=SC2034
PHASES_WITH_INDEX["users"]="03"

# shellcheck disable=SC2329
function users_validate_pub_key() {
    local ssh_key="${1-}"

    if [ -z "$ssh_key" ]; then
        return 0
    fi

    local valid=""
    if ! [[ "$ssh_key" == *.pub ]]; then
        valid="$valid not .pub"
    fi

    local base=""
    if base="$(basename "$ssh_key")"; then
        if [[ "$base" != "authorized_keys" ]]; then
            valid="$valid not authorized_keys"
        else
            valid=""
        fi
    fi

    if [ -n "$valid" ]; then
        echo -n "$valid"
        return 1
    fi

    if [ ! -f "$ssh_key" ]; then
        echo -n "not file"
        return 1
    fi

    if [ ! -s "$ssh_key" ]; then
        echo -n "empty file"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_users_run() {
    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Add users..."

    local cur_index=0

    local -A users=()
    local -A users_no_pass=()
    local -A users_passwords=()
    local -A users_sudo=()
    local -A users_keys=()

    while true; do
        echo_green "Try to extract user from envs with index ${cur_index} ..."
        local username_env="ADD_USER_${cur_index}_NAME"
        # shellcheck disable=SC2155
        local username="$(get_env_value_or_default "$username_env" "")"
        if [ -z "$username" ]; then
            echo_green "No get value with index $cur_index Done getting users from envs"
            break
        fi

        if [[ -v users["$username"] ]]; then
            echo_red "$username already present!"
            return 1
        fi

        local no_pass_env="ADD_USER_${cur_index}_NO_PASSWORD"
        # shellcheck disable=SC2155
        local no_pass="$(get_env_value_or_default "$no_pass_env" "false")"

        local pass_env="ADD_USER_${cur_index}_PASSWORD"
        # shellcheck disable=SC2155
        local pass="$(get_env_value_or_default "$pass_env" "")"

        local sudo_env="ADD_USER_${cur_index}_SUDO"
        # shellcheck disable=SC2155
        local should_sudo="$(get_env_value_or_default "$sudo_env" "false")"

        local ssh_env="ADD_USER_${cur_index}_SSH_KEY"
        # shellcheck disable=SC2155
        local ssh_key="$(get_env_value_or_default "$ssh_env" "")"

        users["$username"]="true"
        users_no_pass["$username"]="$no_pass"
        users_passwords["$username"]="$pass"
        users_sudo["$username"]="$should_sudo"
        users_keys["$username"]="$ssh_key"

        ((cur_index++))
    done

    echo_green "Try to extract users from args..."
    local cur_user_add_arg=0
    while [[ $# -gt 0 ]]; do
        if [[ "${1-}" != "--add-user" ]]; then
            shift
            continue
        fi

        shift

        local arg_username=""
        local arg_no_pass="false"
        local arg_pass=""
        local arg_should_sudo="false"
        local arg_ssh_key=""

        local arg="${1-}"
        while [[ "$arg" == "--" ]]; do
            shift
            case "$1" in
                "--name")
                    arg_username="${2-}"
                    shift
                    shift
                ;;

                "--sudo")
                    arg_should_sudo="$CONST_SHOULD_SUDO"
                    shift
                ;;

                "--password")
                    arg_pass="${2-}"
                    shift
                    shift
                ;;

                "--remove-password")
                    arg_no_pass="$CONST_REMOVE_PASSWORD"
                    shift
                ;;

                "--ssh-pub-key")
                    arg_ssh_key="${2-}"
                    shift
                    shift
                ;;

                *)
                    phase_users_help
                    echo_red "Invalid argument for --add-user $1"
                    return 1
                ;;
            esac

            arg="${1-}"
        done

        if [ -z "$arg_username" ]; then
            echo_red "Username not found for $cur_user_add_arg --add-user argument"
            return 1
        fi

        if [[ "$arg_username" == "--" ]]; then
            echo_red "Username for $cur_user_add_arg --add-user argument is incorrect: --"
            return 1  
        fi

        if [[ -v users["$arg_username"] ]]; then
            echo_red "$arg_username already present!"
            return 1
        fi

        if [[ "$arg_ssh_key" == "--" || "$arg_ssh_key" == "--"* ]]; then
            echo_red "ssh key path $arg_ssh_key for $cur_user_add_arg --add-user argument is incorrect: -- or start from --"
            return 1
        fi

        if [[ "$arg_pass" == "--" || "$arg_pass" == "--"* ]]; then
            echo_yellow "User password for $cur_user_add_arg --add-user argument equal -- or start from --"
            if ! ask_user "It is correct password?" "$CONST_ASK_VAL"; then
                echo_red "Disallow continue with password"
                return 1
            fi
        fi

        users["$arg_username"]="true"
        users_no_pass["$arg_username"]="$arg_no_pass"
        users_passwords["$arg_username"]="$arg_pass"
        users_sudo["$arg_username"]="$arg_should_sudo"
        users_keys["$arg_username"]="$arg_ssh_key"

        ((cur_user_add_arg++))
    done

    if [[ "${#users[@]}" == "0" ]]; then
        echo_green "Not found users to add. Skip"
        return 0
    fi

    local has_invalid_keys=""
    for key_user in "${!users_keys[@]}"; do
        local key="${users_keys["$key_user"]}"
        echo_green "Verify key '$key' for user $key_user"
        local err_ssh_key=""
        if ! err_ssh_key="$(users_validate_pub_key "$key")"; then
            echo_red "ssh pub key file $key for user $key_user invalid: $err_ssh_key"
            has_invalid_keys="true"
        fi
    done

    if [[ "$has_invalid_keys" == "true" ]]; then
        echo_red "^^^ Has invalid ssh pub keys"
        return 1
    fi

    for add_user in "${!users[@]}"; do
        echo_green "Try to add user $add_user ..."

        local user_no_pass="${users_no_pass["$add_user"]}"
        local user_pass="${users_passwords["$add_user"]}"
        local user_should_sudo="${users_sudo["$add_user"]}"
        local user_ssh_key="${users_keys["$add_user"]}"

        if ! add_user "$add_user" "$user_no_pass" "$not_ask" "$user_pass"; then
            return 1
        fi

        if [[ "$user_should_sudo" == "$CONST_SHOULD_SUDO" ]]; then
            echo_green "Add user $add_user to sudo group..."
            if ! add_user_to_group "$add_user" "sudo"; then
                return 1
            fi

            echo_green "Add user $add_user to sudoers..."
            if ! add_user_to_sudoers "$add_user" "$not_ask"; then
                return 1
            fi
        fi

        if [ -n "$user_ssh_key" ]; then
            echo_green "Add public keys for $add_user from $user_ssh_key ..."
            if ! add_pubkey_for_user "$add_user" "$user_ssh_key" "$not_ask"; then
                return 1
            fi
        fi

        echo_green "User $add_user added!"
    done
}

# shellcheck disable=SC2329
function phase_users_help() {
    echo -n "
    Add users
    Options:
      --add-user -- --name 'name' [-- --sudo | -- --password 'PASSWORD' | -- --remove-password -- | --ssh-pub-key PATH]
        Provide user settings.
        Can be multiple time.
        Script parse every own sub arguments while get -- argument
        Sub args:
          --name     - name of user. required
          --sudo     - if passed add user to sudo group and sudoers. Default no add to sudo.
          --password - if passed use PASSWORD as password. If not passed 
                       and not use --remove-password ask run passwd as not interactive
          --remove-password - if passed remove password for user.
          --ssh-pub-key - path to ssh public key to add for user (should suffix .pub) or autorised keys file
    You can use next envs for add users.
    every env should has prefix ADD_USER_\${INDEX}_ when INDEX index for user started from 0 
    Script can try to get env ADD_USER_\${INDEX}_NAME and if next index env is not found stop adding
    Envs:
      ADD_USER_\${INDEX}_NAME        - user name
      ADD_USER_\${INDEX}_SUDO        - if has  'true' value add to sudo, othervise not add 
      ADD_USER_\${INDEX}_PASSWORD    - password for set
      ADD_USER_\${INDEX}_NO_PASSWORD - if has true value - remove password
      ADD_USER_\${INDEX}_SSH_KEY     - path to ssh pub key (should suffix .pub) or autorised keys file
"
}

# shellcheck disable=SC2329
function phase_users_disable_env() {
    echo -n "DISABLE_USERS"
}