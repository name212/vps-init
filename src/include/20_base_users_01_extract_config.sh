#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function users_extract_configuration() {
    local users_dest="$1"
    if [ -z "$users_dest" ]; then
        echo_error "users destination array name not passed"
        return 1
    fi
    shift

    local users_no_pass_dest="$2"
    if [ -z "$users_no_pass_dest" ]; then
        echo_error "users no pass setting destination array name not passed"
        return 1
    fi
    shift
    
    local users_passwords_dest="$3"
    if [ -z "$users_passwords_dest" ]; then
        echo_error "users password setting destination array name not passed"
        return 1
    fi
    shift
    
    local users_sudo_dest="$4"
    if [ -z "$users_sudo_dest" ]; then
        echo_error "users sudo setting destination array name not passed"
        return 1
    fi
    shift
    
    local users_sudo_no_pass_dest="$5"
    if [ -z "$users_sudo_no_pass_dest" ]; then
        echo_error "users sudo no password setting destination array name not passed"
        return 1
    fi
    shift
    
    local users_keys_dest="$6"
    if [ -z "$users_keys_dest" ]; then
        echo_error "users keys setting destination array name not passed"
        return 1
    fi
    shift

    local -n users_arr="$users_dest"
    local -n users_no_pass_arr="$users_no_pass_dest"
    local -n users_passwords_arr="$users_passwords_dest"
    local -n users_sudo_arr="$users_sudo_dest"
    local -n users_sudo_no_pass_arr="$users_sudo_no_pass_dest"
    local -n users_keys_arr="$users_keys_dest"

    local cur_index=0

    while true; do
        echo_debug "Try to extract user from envs with index ${cur_index} ..."
        local username_env="ADD_USER_${cur_index}_NAME"
        # shellcheck disable=SC2155
        local username="$(get_env_value_or_default "$username_env" "")"
        if [ -z "$username" ]; then
            echo_info "No get value with index $cur_index Done getting users from envs"
            break
        fi

        if [[ -v users_arr["$username"] ]]; then
            echo_error "$username already present!"
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

        local sudo_no_pass_env="ADD_USER_${cur_index}_SUDO_NO_PASS"
        # shellcheck disable=SC2155
        local sudo_no_pass="$(get_env_value_or_default "$sudo_no_pass_env" "false")"

        local ssh_env="ADD_USER_${cur_index}_SSH_KEY"
        # shellcheck disable=SC2155
        local ssh_key="$(get_env_value_or_default "$ssh_env" "")"

        users_arr["$username"]="true"
        users_no_pass_arr["$username"]="$no_pass"
        users_passwords_arr["$username"]="$pass"
        users_sudo_arr["$username"]="$should_sudo"
        users_sudo_no_pass_arr["$username"]="$sudo_no_pass"
        users_keys_arr["$username"]="$ssh_key"

        ((cur_index++))
    done

    echo_debug "Try to extract users from args..."
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
        local arg_sudo_no_pass="false"
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

                "--sudo-no-pass")
                    arg_sudo_no_pass="$CONST_SUDO_NO_PASS"
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
                    echo_error "Invalid argument for --add-user $1"
                    return 1
                ;;
            esac

            arg="${1-}"
        done

        if [ -z "$arg_username" ]; then
            echo_error "Username not found for $cur_user_add_arg --add-user argument"
            return 1
        fi

        if [[ "$arg_username" == "--" ]]; then
            echo_error "Username for $cur_user_add_arg --add-user argument is incorrect: --"
            return 1  
        fi

        if [[ -v users_arr["$arg_username"] ]]; then
            echo_error "$arg_username already present!"
            return 1
        fi

        if [[ "$arg_ssh_key" == "--" || "$arg_ssh_key" == "--"* ]]; then
            echo_error "ssh key path $arg_ssh_key for $cur_user_add_arg --add-user argument is incorrect: -- or start from --"
            return 1
        fi

        if [[ "$arg_pass" == "--" || "$arg_pass" == "--"* ]]; then
            echo_warn "User password for $cur_user_add_arg --add-user argument equal -- or start from --"
            if ! ask_user "It is correct password?" "$CONST_ASK_VAL"; then
                echo_error "Disallow continue with password"
                return 1
            fi
        fi

        users_arr["$arg_username"]="true"
        # shellcheck disable=SC2034
        users_no_pass_arr["$arg_username"]="$arg_no_pass"
        # shellcheck disable=SC2034
        users_passwords_arr["$arg_username"]="$arg_pass"
        # shellcheck disable=SC2034
        users_sudo_arr["$arg_username"]="$arg_should_sudo"
        # shellcheck disable=SC2034
        users_sudo_no_pass_arr["$arg_username"]="$arg_sudo_no_pass"
        # shellcheck disable=SC2034
        users_keys_arr["$arg_username"]="$arg_ssh_key"

        ((cur_user_add_arg++))
    done

    return 0
}

# shellcheck disable=SC2329
function users_configuration_help() {
    echo -n "
    Add users
    Options:
      --add-user -- --name 'name' [-- --sudo | -- --password 'PASSWORD' | -- --remove-password -- | --ssh-pub-key PATH_OR_KEY]
        Provide user settings.
        Can be multiple time.
        Script parse every own sub arguments while get -- argument
        Sub args:
          --name            - name of user. required
          --sudo            - if passed add user to sudo group and sudoers.
          --sudo-no-pass    - if passed remove ask sudo password for user.
          --password        - if passed use PASSWORD as password. If not passed 
                              and not use --remove-password ask run passwd as not interactive
          --remove-password - if passed remove password for user.
          --ssh-pub-key     - path to ssh public key to add for user (should suffix .pub) for authorized keys file or key string
    You can use next envs for add users.
    every env should has prefix ADD_USER_\${INDEX}_ when INDEX index for user started from 0 
    Script can try to get env ADD_USER_\${INDEX}_NAME and if next index env is not found stop adding
    Envs:
      ADD_USER_\${INDEX}_NAME         - user name
      ADD_USER_\${INDEX}_SUDO         - if has '$CONST_SHOULD_SUDO' value add to sudo, otherwise not add 
      ADD_USER_\${INDEX}_SUDO_NO_PASS - if has '$CONST_SUDO_NO_PASS' value add to sudo, otherwise not add 
      ADD_USER_\${INDEX}_PASSWORD     - password for set
      ADD_USER_\${INDEX}_NO_PASSWORD  - if has '$CONST_REMOVE_PASSWORD' value - remove password
      ADD_USER_\${INDEX}_SSH_KEY      - path to ssh pub key (should suffix .pub) for authorized keys file or key string
"
}
