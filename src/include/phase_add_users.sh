#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
PHASES_WITH_INDEX["users"]="02"


function phase_users_run() {
    if [[ "${DISABLE_USERS-no}" == "true" ]]; then
        echo_yellow "Skip install werf!"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Add users..."

    local cur_index=0

    while true; do
        echo_green "Try to extract user from envs with index  ${cur_index}..."
        # shellcheck disable=SC2034
        local username_env="ADD_USER_${cur_index}_NAME"
        # shellcheck disable=SC1035
        # shellcheck disable=SC2155
        local username="$(!username_env:-)"
        if [ -z "$username" ]; then
            echo_green "No get value with index $cur_index Done getting users from envs"
            return 0
        fi

        # shellcheck disable=SC2034
        local no_pass_env="ADD_USER_${cur_index}_NO_PASSWORD"
        # shellcheck disable=SC1035
        # shellcheck disable=SC2155
        local no_pass="$(!no_pass_env:-flase)"

        # shellcheck disable=SC2034
        local pass_env="ADD_USER_${cur_index}_PASSWORD"
        # shellcheck disable=SC1035
        # shellcheck disable=SC2155
        local pass="$(!pass_env:-)"

        # shellcheck disable=SC2034
        local sudo_env="ADD_USER_${cur_index}_SUDO"
        # shellcheck disable=SC1035
        # shellcheck disable=SC2155
        local should_sudo="$(!sudo_env:-false)"

        # shellcheck disable=SC2034
        local ssh_env="ADD_USER_${cur_index}_SSH_KEY"
        # shellcheck disable=SC1035
        # shellcheck disable=SC2155
        local ssh_key="$(!ssh_env:-false)"

        if ! add_user "$username" "$no_pass" "$pass"; then
            return 1
        fi

        if [[ "$should_sudo" == "true" ]]; then
            if ! add_user_to_group "$username" "sudo"; then
                return 1
            fi

            if ! add_user_to_sudoers "$username" "$not_ask"; then
                return 1
            fi
        fi

        if [ -n "$ssh_key" ]; then
            if ! add_pubkey_for_user "$username" "$ssh_key" "$not_ask"; then
                return 1
            fi
        fi

        echo_green "User $username added!"

    done
}

function phase_users_help() {
    echo "Add users
  Options:
    $(not_ask_arg_help)
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
        --ssh-pub-key - path to ssh public key to add for user
    You can use next envs for add users.
    every env should has prefix ADD_USER_\${INDEX}_ when INDEX index for user started from 0 
    Script can try to get env ADD_USER_\${INDEX}_NAME and if next index env is not found stop adding
    Envs:
      ADD_USER_\${INDEX}_NAME        - user name
      ADD_USER_\${INDEX}_SUDO        - if has  'true' value add to sudo, othervise not add 
      ADD_USER_\${INDEX}_PASSWORD    - password for set
      ADD_USER_\${INDEX}_NO_PASSWORD - if has true value - remove password
      ADD_USER_\${INDEX}_SSH_KEY     - path to ssh pub key
"
}

function phase_users_disable_env() {
    echo -n "DISABLE_USERS"
}