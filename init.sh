#!/usr/bin/env bash

set -Eeuo pipefail

bin_name="$0"

declare -A PHASES_WITH_INDEX=()
declare -a COMMANDS_LIST=()

# Start src/include/01-base_echo.sh

function echo_red(){
    echo -e "\033[1;31m$1\033[0m"
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m"
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m"
}

# End src/include/01-base_echo.sh

# Start src/include/02-args.sh

export CONST_FLAG_SET="true"
export CONST_NO_VALIDATE="no_validate"
export CONST_IS_FLAG="true"
export CONST_NOT_FLAG="false"
export CONST_ARG_NOT_PASSED="false"
export CONST_ARG_PASSED="true"
export CONST_NOT_ASK_VAL="true"
export CONST_ASK_VAL=""

function disable_env() {
    local phase="$1"

    local env_name=""

    local env_fun="phase_${phase}_disable_env"
    if declare -F "$env_fun" > /dev/null; then
        env_name="$("$env_fun")"
    fi

    echo -n "$env_name"
}

function phase_is_not_disabled() {
    local phase="$1"

     # shellcheck disable=SC2155
    local env_name="$(disable_env "$phase")"

    if [ -z "$env_name" ]; then
        return 0
    fi

    if [ -v "$env_name" ]; then
        if [[ "${!env_name:-}" == "$CONST_FLAG_SET" ]]; then
            return 1
        fi
    fi

    return 0
}

function disable_help() {
    local phase="$1"

    # shellcheck disable=SC2155
    local env_name="$(disable_env "$phase")"

    if [ -n "$env_name" ]; then
        echo "Can be desabled with set env ${env_name}=true"
        return 0
    fi

    echo "This phase is required and not be disabled!"
}

function extract_argument() {
    local arg_name="$1"
    local env_name="$2"
    local is_flag="$3"
    local validator="$4"

    shift
    shift
    shift
    shift

    local val=""

    local arg_passed="$CONST_ARG_NOT_PASSED"

    local extract_and_break=""
    for arg in "$@"; do
        if [[ "$extract_and_break" == "true" ]]; then
            val="$arg"
            break
        fi

        if [[ "$arg" == "$arg_name" ]]; then
            arg_passed="$CONST_ARG_PASSED"
            if [[ "$is_flag" == "$CONST_IS_FLAG" ]]; then
                val="$CONST_FLAG_SET"
            else
                extract_and_break="true"
            fi
        fi
    done

    if [ -n "$env_name" ]; then
        if [ -v "$env_name" ]; then
            val="${!env_name:-}"
            arg_passed="$CONST_ARG_PASSED"
        fi
    fi

    if [[ "$is_flag" == "$CONST_IS_FLAG" ]]; then
        echo -n "$val"
        return 0
    fi

    if [[ "$validator" == "" || "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$val"
        return 0
    fi

    if ! declare -F "$validator" > /dev/null; then
        echo_red "Internal error: '$validator' func not declared!"
        return 1
    fi

    local prepared
    if ! prepared="$($validator "$val" "$arg_passed")"; then
        echo_red "Incorrect: $prepared"
        return 1
    fi

    echo -n "$prepared"
    return 0
}

function arg_flag_is_set() {
    # shellcheck disable=SC2155
    local res="$(extract_argument "$@")"
    if [[ "$res" == "$CONST_FLAG_SET" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function parse_not_ask() {
    if arg_flag_is_set "--not-ask" "NOT_ASK" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@"; then
        echo -n "$CONST_NOT_ASK_VAL"
        return 0
    fi

    echo "$CONST_ASK_VAL"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_not_empty_file() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo -n ""
        return 0
    fi

    if [ -z "$val" ]; then
        echo "Empty file path"
        return 1 
    fi

    local real=""

    if ! real="$(realpath "$val")"; then
        echo "cannot extract real path for $val"
        return 1
    fi

    if [ ! -f "$real" ]; then
        echo "$val is not file!"
        return 1
    fi

    if [ ! -s "$real" ]; then
        echo "$val is empty file!"
        return 1
    fi

    echo -n "$real"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_not_empty() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty arg val"
        return 1 
    fi

    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_number() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty arg val"
        return 1 
    fi

    if ! [[ $val =~ ^[0-9]+$ ]]; then
        echo_red "$val is not number!"
        return 1
    fi

    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function get_env_value_or_default() {
    local var_name="$1"
    local default_val="${2-}"

    if ! [[ -v "$var_name" ]]; then
        echo -n "$default_val"
        return 0
    fi

    echo -n "${!var_name}"
    return 0
}

# End src/include/02-args.sh

# Start src/include/03-base_input.sh

# shellcheck disable=SC2329
function ask_user() {
    local prompt="$1"
    local not_ask="${2-no}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local answer=""

    read -p "${prompt} [y/n]: " answer

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# End src/include/03-base_input.sh

# Start src/include/04-base_fs.sh

# shellcheck disable=SC2329
function delete_file() {
    if ! rm "$1"; then
        echo_red "$1 not deleted!"
        return 1
    fi

    echo_green "$1 deleted"
}

# shellcheck disable=SC2329
function replace_file() {
    local src="$1"
    local dest="$2"
    local title="${3-No title}"
    local remove_src="${4-true}"
    local not_ask="${5-false}"

    if [ -z "$src" ]; then
        echo_red "Source file not passed"
        return 1
    fi

    if [ ! -f "$src" ]; then
        echo_red "Source file $src is not file"
        return 1
    fi

    if [ -z "$dest" ]; then
        echo_red "Dest file not passed"
        return 1
    fi

    echo_green "--- $title from $src ---"
    cat "$src"
    echo_green "--- End file ---"
    echo ""
    
    echo_green "--- Diff ---"
    if [ ! -f "$dest" ]; then
        echo_green "Add new file with content:"
        cat "$src"
    else
        diff "$src" "$dest" || true
    fi

    echo_green "--- End diff ---"

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        echo_green "$title delete source $src"
        if ! rm "$src"; then
            echo_yellow "$title source file $src not deleted!"
            return 0
        fi
        echo_red "Disallow replace $dest"
        return 1
    fi

    if ! cp "$src" "$dest"; then
        echo_red "$title not replaced. Source $src not deleted"
        return 1
    fi

    if [[ "$remove_src" == "true" ]]; then
        echo_green "$title delete source $src"
        if ! rm "$src"; then
            echo_yellow "$title source file $src not deleted!"
            return 0
        fi
    fi

    return 0
}

# End src/include/04-base_fs.sh

# Start src/include/base_download.sh

# shellcheck disable=SC2329
function download_url(){
    local url="$1"
    local dest="$2"

    if ! curl -fsSL "$url" -o "$dest"; then
        return 1 
    fi

    return 0
}

# shellcheck disable=SC2329
function download_script_and_run() {
    local url="$1"
    local not_ask="$2"

    shift
    shift

    local script_args=()

    if [ "$#" -gt 2 ]; then
        script_args=( "$@" )
    fi

    # shellcheck disable=SC2155
    local script_path="$(mktemp)"

    echo_green "Download script $url to ${script_path}..."

    download_url "$url" "$script_path"

    chmod 700 "$script_path"

    # shellcheck disable=SC2154
    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        echo_green "Run script ${script_path} without ask..."
        "$script_path" "${script_args[@]}"
        return $?
    fi

    echo_green "If you do not output script (big file) now you can use 'less ${script_path}' before approve"

    if ask_user "Output $script_path ?"; then
        cat "$script_path"
    fi

    if ! ask_user "Run $script_path ?"; then
        echo_red "Disallow run $script_path"
        delete_file "$script_path" || true
        return 1
    fi

    if ! "$script_path" "${script_args[@]}"; then 
        echo_red "Run $script_path failed!"
        delete_file "$script_path" || true
        return 1
    fi

    delete_file "$script_path" || true
    return 0
}

# End src/include/base_download.sh

# Start src/include/base_pkg.sh

# shellcheck disable=SC2329
function install_packages() {
    echo_green "Install apt packages $* ..."
    if ! apt update; then 
        echo_red "Cannot run apt update!"
        return 1
    fi

    if ! apt install -y "$@"; then
        echo_red "Cannot run apt install!"
        return 1
    fi

    echo_green "Packages $* installed!"
}

# shellcheck disable=SC2329
function check_packages_installed() {
    local all="true"
    while [[ $# -gt 0 ]]; do
        local name="$1"
        if ! dpkg-query -s "$name" &> /dev/null; then
            echo_green "$name not installed..."
            all="false"
        fi
        shift
    done

    if [[ "$all" == "false" ]]; then
        return 1
    fi
    
    return 0
}

# shellcheck disable=SC2329
function remove_packages() {
    local -a for_remove=()

    while [[ $# -gt 0 ]]; do
        local name="$1"
        if dpkg-query -s "$name" &> /dev/null; then
            for_remove+=("$name")
        fi
        shift
    done

    if [[ "${#for_remove[@]}" == "0" ]]; then
        echo_green "All passed packages already removed"
        return 0
    fi

    echo_green "Remove packages ${for_remove[*]}"
    
    if ! apt purge -y --auto-remove "${for_remove[@]}"; then
        echo_red "Some packages not removed!"
        return 1
    fi

    return 0
}

# End src/include/base_pkg.sh

# Start src/include/base_user.sh

export CONST_REMOVE_PASSWORD="true"

# shellcheck disable=SC2329
function update_passwd_for_user() {
    local name="$1"
    local remove_password="${2-false}"
    local password="${3-}"

     if [[ "$remove_password" == "$CONST_REMOVE_PASSWORD" ]]; then
        echo_green "Remove password for user ${name}..."
        if ! passwd -d "$name"; then
            echo_red "Password not removed for $name"
            return 1
        fi

        return 0
    fi

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

    if ! passwd "$name" <<<"$enter_pass"; then
        echo_red "Cannot update passed password for $name"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function add_user() {
    local name="$1"
    local remove_password="${2-false}"
    local not_ask="${3-false}"
    local password="${4-}"

    if [ -z "$name" ]; then
        echo_red "User name is empty"
        return 1
    fi

    local user_exists="true"

    if ! getent passwd "$name" > /dev/null; then
        echo_green "Add user ${name}..."

        if ! useradd -m -s /bin/bash "$name"; then
            echo_red "User $name not added!"
            return 1
        fi

        user_exists="false"
    fi

    if [[ "$user_exists" == "true" ]]; then
        if ! ask_user "User $name exists. Update password?" "$not_ask"; then
            echo_yellow "Skip update password for $name"
            echo_green "User ${name} updated!"
            return 0
        fi
    fi
    
    if ! update_passwd_for_user "$name" "$remove_password" "$password"; then 
        return 1
    fi

    echo_green "User ${name} added or updated!"
}

# shellcheck disable=SC2329
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

# shellcheck disable=SC2329
function add_user_to_sudoers() {
    local name="$1"
    local not_ask="${2-no}"

    if [ -z "$name" ]; then
        echo_red "user name did not pass"
        return 1
    fi

    local sudoers_str="$name    ALL=(ALL:ALL) ALL"

    local sudoers_path="/etc/sudoers"

    if grep -q "$sudoers_str" "$sudoers_path"; then
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

    local ssh_dir="${user_home}/.ssh"

    if ! mkdir -p "$ssh_dir"; then
        echo_red "cannot create $ssh_dir dir for $name"
        return 1
    fi

    if ! chmod 700 "$ssh_dir"; then
        echo_red "cannot chmod $ssh_dir dir for $name"
        return 1
    fi

    if ! chown "${name}:${name}" "$ssh_dir"; then
        echo_red "cannot chown $ssh_dir dir for $name"
        return 1
    fi

    local auth_keys_file="${ssh_dir}/authorized_keys"

    # shellcheck disable=SC2155
    local tmp_file="$(mktemp)"

    if [ -f "$auth_keys_file" ]; then
        if ! cp "$auth_keys_file" "$tmp_file"; then
            delete_file "$tmp_file" || true
            echo_red "cannot copy $auth_keys_file to $tmp_file for add key for $name"
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
        echo_red "cannot chmod $auth_keys_file file for $name"
        return 1
    fi

    if ! chown "${name}:${name}" "$auth_keys_file"; then
        echo_red "cannot chown $auth_keys_file file for $name"
        return 1
    fi

    return 0
}

# End src/include/base_user.sh

# Start src/include/cmd_gitlab_register.sh

COMMANDS_LIST+=("gitlab_register_runner")

export CONST_GITLAB_SERVICE_NAME="gitlab-runner.service"

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_run() {
    if ! command -v gitlab-runner &> /dev/null; then
        echo_red "gitlab runner is not installed!"
        echo_red "Please init server or install with --phase gitlab first."
        return 1
    fi

    if ! systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_red "gitlab runner service is not active!"
        echo_red "Please init server or install with --phase gitlab first."
        return 1
    fi

    local runner_config=""

    if ! runner_config="$(extract_argument "--gtlab-runner-config" "GITLAB_RUNNER_CONFIG" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_red "Gitlab runner config: $runner_config"
        return 1
    fi

    if [ -n "$runner_config" ]; then
        echo_green "Load runner config $runner_config"
        # shellcheck disable=SC1090
        set -a && source "$runner_config" && set +a
    fi

    local errors=""

    if [ -z "$GITLAB_RUNNER_URL" ]; then 
        errors="${errors} GITLAB_RUNNER_URL not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_TOKEN" ]; then 
        errors="${errors} GITLAB_RUNNER_TOKEN not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_DESC" ]; then 
        errors="${errors} GITLAB_RUNNER_DESC not provided in config"
    fi

    if [ -z "$GITLAB_RUNNER_TAGS" ]; then 
        errors="${errors} GITLAB_RUNNER_TAGS not provided in config"
    fi

    if [ -n "$errors" ]; then
        echo_red "$errors"
        return 1
    fi

    local runners=""
    if ! runners="$(gitlab-runner list -c /etc/gitlab-runner/config.toml)"; then
        echo_red "Cannot list runners!"
        return 1
    fi

    local runner_name="$GITLAB_RUNNER_DESC"

    if grep -q "$runner_name" <<<"$runners"; then
        echo_green "Runner $runner_name already registered!"
        return 0
    fi

    local register_args=(
        "--non-interactive"
        "--url" 
        "$GITLAB_RUNNER_URL"
        "--token" 
        "$GITLAB_RUNNER_TOKEN"
        "--description" 
        "$runner_name"
        "--tag-list"
        "$GITLAB_RUNNER_TAGS"
        "--executor" 
        "shell"
    )

    if ! gitlab-runner register "${register_args[@]}"; then
        echo_red "Cannot register runner ${runner_name}!"
        return 1
    fi
    
    echo_green "Runner ${runner_name} registered!"
}

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_help() {
    echo -n "
    Register gitlab runner.
    Options:
      --gtlab-runner-config PATH
         Path to configuration to register runner.
         Should be sh script with export next variables:
           GITLAB_RUNNER_URL   - url to register gitlab runner.
           GITLAB_RUNNER_TOKEN - token to register runner
           GITLAB_RUNNER_DESC  - name or description of new runner
           GITLAB_RUNNER_TAGS  - comma-separated tags of runner.
         All parameters is required.
         Can be provided with env GITLAB_RUNNER_CONFIG
    Also you can provide envs without config.
"
}

# End src/include/cmd_gitlab_register.sh

# Start src/include/phase_01_base_pkgs.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["base_pkgs"]="01"

# shellcheck disable=SC2329
function phase_base_pkgs_run() {
    echo_green "Install base packages..."

    local packages=(
        "bash-completion" 
        "ca-certificates" 
        "nano" 
        "vim" 
        "less" 
        "dnsutils"
        "bind9-dnsutils"
        "iputils-ping" 
        "htop" 
        "mc" 
        "curl" 
        "jq" 
        "yq"
        "libc-bin"
        "diffutils"
        "git"
        "procps"
        "tzdata"
        "gnupg"
        "apt-transport-https"
        "chrony"
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

# shellcheck disable=SC2329
function phase_base_pkgs_help() {
    echo -n "
    Install base packages
    No options.
"
}

# shellcheck disable=SC2329
function phase_base_pkgs_disable_env() {
    echo -n ""
}

# End src/include/phase_01_base_pkgs.sh

# Start src/include/phase_02_remove_upgrade.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_upgrade"]="02"

# shellcheck disable=SC2329
function phase_remove_upgrade_run() {
    echo_green "Remove unattended upgrades..."

    if ! remove_packages "unattended-upgrades"; then
        return 1 
    fi

    local -a timers=("apt-daily.timer" "apt-daily-upgrade.timer")

    echo_green "Stop and disable timers ${timers[*]} ..."
    
    if ! systemctl disable "${timers[@]}"; then 
        echo_red "Cannot disable timers"
        return 1
    fi

    if ! systemctl stop "${timers[@]}"; then 
        echo_red "Cannot stop timers"
        return 1
    fi

    echo_green "Unattended upgrades removed!"
    return 0
}

# shellcheck disable=SC2329
function phase_remove_upgrade_help() {
    echo -n "
    Remove unattended upgrades.
    No options.
"
}

# shellcheck disable=SC2329
function phase_remove_upgrade_disable_env() {
    echo -n "DISABLE_REMOVE_UPGRADE"
}

# End src/include/phase_02_remove_upgrade.sh

# Start src/include/phase_03_add_users.sh

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

# End src/include/phase_03_add_users.sh

# Start src/include/phase_04_change_hostname.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["hostname"]="04"

# shellcheck disable=SC2329
function phase_hostname_run() {
    local new_hostname=""

    if ! new_hostname="$(extract_argument "--new-hostname" "NEW_HOSTNAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_red "New hostname: $new_hostname"
        return 1
    fi

    echo_green "Prepare hostname..."

    local cur_hostanme=""
    if ! cur_hostanme="$(hostnamectl hostname)"; then
        echo_red "Cannot get current host name!"
        return 1
    fi

    if [[ "$new_hostname" == "$cur_hostanme" ]]; then
        echo_green "Hostname already set to $new_hostname!"
    else
        if ! hostnamectl set-hostname "$new_hostname"; then
            echo_red "Cannot set hostname to $new_hostname!"
            return 1
        fi
    fi

    local hosts_file="/etc/hosts"
    local tab=$'\t'
    local hostname_hosts="127.0.1.1${tab}${new_hostname}"

    if grep -q "$hostname_hosts" "$hosts_file"; then
        echo_green "$new_hostname added to $hosts_file for alias to 127.0.1.1"
    else
        echo_green "Prepare hostname. Add new hostname for alias 127.0.1.1 to ${hosts_file} ..."

        {
            echo ""
            echo "# local for ${new_hostname}"
            echo "$hostname_hosts"
            echo ""
        } >> "$hosts_file"

        echo_green "--- New $hosts_file ---"
        cat "$hosts_file"
        echo_green "--- End file ---"
    fi

    echo_green "Hostname changed!"

    return 0
}

# shellcheck disable=SC2329
function phase_hostname_help() {
    echo "
    Change hostname
    Options:
      --new-hostname hostaname
        Set new hostname.
        Can be provided with env NEW_HOSTNAME
"
}

# shellcheck disable=SC2329
function phase_hostname_disable_env() {
    echo -n "DISABLE_HOSTNAME"
}

# End src/include/phase_04_change_hostname.sh

# Start src/include/phase_05_sshd.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="05"

# shellcheck disable=SC2329
function sshd_disable_systemd_socket() {
    echo_green "Enable sshd service..."
    if ! systemctl enable --now ssh.service; then
        echo_red "Cannot enable ssh.service"
        return 1
    fi

    echo_green "SSHD service enabled! Restart..."

    if ! systemctl restart ssh.service; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_green "Stop sshd systemd socket.."
    if ! systemctl stop ssh.socket; then
        echo_red "Cannot stop ssh.socket"
        return 1
    fi

    echo_green "Disable sshd systemd socket..."
    if ! systemctl disable --now ssh.socket; then
        echo_red "Cannot disabe ssh.socket"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_verify_and_restart() {
    local setting="${1,,}"

    if ! sshd -t; then
        echo_red "Test sshd config failed!"
        return 1 
    fi

    local conf_for_check=""
    if ! conf_for_check="$(sshd -T)"; then
        echo_red "Cannot get sshd config from sshd!"
        return 1 
    fi

    if ! grep -q "$setting" <<<"$conf_for_check"; then
        echo_red "Cannot found setting '$setting' in sshd config!"
        return 1 
    fi

    echo_green "SSHD config is valid! Restart..."

    if ! systemctl restart ssh.service; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_apply_setting() {
    local setting="${1}"
    local conf_file="${2}"

    if [ ! -f "$conf_file" ]; then
        echo "$setting" > "$conf_file" 
    fi

    if ! grep -q "$setting" "$conf_file"; then
        echo_yellow "Change to new sshd port setting to '$setting'"
        echo "$setting" > "$conf_file"
    fi

    if ! chmod 600 "$conf_file"; then
        echo_yellow "Cannot change mode for config file $conf_file"
    else
        if ! chown "root:root" "$conf_file"; then
            echo_yellow "Cannot change owner to root for config file $conf_file"
        fi
    fi

    if ! sshd_verify_and_restart "$setting"; then
        echo_yellow "Remove config $conf_file file and restart..."
        if ! delete_file "$conf_file"; then
            echo_red "Cannot remove port file config $conf_file"
        fi

        if ! systemctl restart ssh.service; then
            echo_red "!!! SSHD was not restarted !!!"
        fi

        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_run() {
    local port=""

    if ! port="$(extract_argument "--sshd-port" "SSHD_PORT" "$CONST_NOT_FLAG" "validate_arg_number" "$@")"; then
        echo_red "SSHD port: $port"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Prepare sshd..."

    local base_cfgs_dir="/etc/ssh/sshd_config.d"

    if ! sshd_disable_systemd_socket; then
        return 1
    fi

    echo_green "Prepare sshd. Apply new port..."

    local port_setting="Port $port"
    local port_file="${base_cfgs_dir}/99_z_port.conf"

    if ! sshd_apply_setting "$port_setting" "$port_file"; then
        echo_red "Cannot apply sshd port setting '$port_setting'"
        return 1
    fi

    echo_green "Prepare sshd. New port applyer!"
    echo_green "Please verify that ssh available on port $port"

    if ! ask_user "SSH available? Continue?" "$not_ask"; then
        echo_red "Disallow continue"
        return 1
    fi

    echo_green "Prepare sshd. Disable root login..."

    local auth_present=""
    # shellcheck disable=SC2044
    for auth_file in $(find /home -name "authorized_keys"); do 
        if [ -s "$auth_file" ]; then
            echo_green "Found not empty authorized_keys $auth_file"
            auth_present="true"
        fi 
    done

    if [ -z "$auth_present" ]; then
        echo_red "Not found any non zero authorized_keys files. Cannot continue"
        return 1
    fi

    local root_setting="PermitRootLogin no"
    local root_file="${base_cfgs_dir}/99_z_disable_root.conf"

    if ! sshd_apply_setting "$root_setting" "$root_file"; then
        echo_red "Cannot disable root login '$root_setting'"
        return 1
    fi

    echo_green "Prepare sshd. Root login disabled!"
    echo_green "Please verify that ssh not avaiable with root"

    if ! ask_user "SSH not available with root? Continue?" "$not_ask"; then
        echo_red "Disallow continue"
        return 1
    fi

    echo_green "Prepare sshd. Disable password auth..."

    local pass_setting="PasswordAuthentication no"
    local pass_file="${base_cfgs_dir}/99_z_disable_pass_auth.conf"

    if ! sshd_apply_setting "$pass_setting" "$pass_file"; then
        echo_red "Cannot apply sshd port setting '$pass_setting'"
        return 1
    fi

    echo_green "Prepare sshd. Password auth disabled!"
    echo_green "Please verify that ssh not avaiable with password auth"
    echo_green "Can be verify with command:" 
    echo_green "ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no YOUR_USER@HOST"

    if ! ask_user "SSH password auth not available? Continue?" "$not_ask"; then
        echo_red "Disallow continue"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_help() {
    echo -n "
    Change sshd port remove pass auth and root login
    Options:
      --sshd-port PORT
         Replace to new port.
         Can be provided with env SSHD_PORT
"
}

# shellcheck disable=SC2329
function phase_sshd_disable_env() {
    echo -n "DISABLE_PREPARE_SSHD"
}

# End src/include/phase_05_sshd.sh

# Start src/include/phase_06_docker.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["docker"]="06"

# shellcheck disable=SC2329
function phase_docker_run() {
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

# End src/include/phase_06_docker.sh

# Start src/include/phase_80_gitlab.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["gitlab"]="80"

# shellcheck disable=SC2329
function gitlab_prepare_runner_service() {
    local service_name="$1"
    local username="$2"
    local not_ask="${3-no}"

    local exec_str=""

    if systemctl is-active "$service_name"; then
        if ! exec_str="$(systemctl show "$service_name" --no-pager -p ExecStart)"; then
            echo_red "Cannot get exec string for gitlab service"
            return 1
        fi
    else 
        echo_green "gitlab service not active!"
    fi

    if [ -z "$exec_str" ]; then
        echo_red "exec string for gitlab service is empty"
        return 1
    fi

    if grep -q "user $username" <<<"$exec_str"; then
        echo_green "Runner $service_name already will run with user!"
        if ! systemctl daemon-reload; then
            echo_red "Cannot run daemon reload!"
            return 1
        fi
        return 0
    fi

    echo_green "Gitlab service probably has not user: ${exec_str}"

    if ! ask_user "Do you want to reinstall service?" "$not_ask"; then
        echo_red "Disallow reinstall runner service!"
        return 1
    fi

    echo_green "Start reinstall gitlab service..."

    if ! sudo systemctl stop "$service_name"; then
        echo_red "Cannot stop gitlab runner service!"
        return 1
    fi

    echo_green "Start uninstall gitlab service..."

    if ! gitlab-runner uninstall; then
        echo_red "Cannot uninstall gitlab runner service!"
        return 1
    fi

    local install_args=(
        "--service" 
        "$service_name"
        "--user"
        "$username"
        "--working-directory" 
        "/home/$username"
    )

    echo_green "Start install gitlab service..."

    if ! gitlab-runner install "${install_args[@]}"; then
        echo_red "Cannot install gitlab runner service!"
        return 1
    fi

    echo_green "Reload systemd..."

    if ! systemctl daemon-reload; then
        echo_red "Cannot run daemon reload!"
        return 1
    fi

    echo_green "Start gitlab service..."

    if ! systemctl start "$service_name"; then
        echo_red "Cannot run gitlab service!"
        return 1
    fi

    echo_green "Enable gitlab service..."

    if ! systemctl enable "$service_name"; then
        echo_red "Cannot enable gitlab service!"
        return 1
    fi
    
    echo_green "Gitlab service reinstalled with new user!"
}

# shellcheck disable=SC2329
function phase_gitlab_run() {
    echo_green "Install gitlab runner..."

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Create user for runner..."

    local username="gitlab-runner"
    
    if ! add_user "$username" "$CONST_REMOVE_PASSWORD" "$not_ask" ""; then
        return 1
    fi

    local package="gitlab-runner"

    if ! check_packages_installed "$package"; then
        echo_green "Prepare gitlab apt repository..."

        local url="https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh"

        if ! download_script_and_run "$url" "$not_ask"; then
            return 1
        fi

        echo_green "Install gitlab runner package ${package}..."

        if ! install_packages "$package"; then
            echo_red "gitlab runner not installed!"
            return 1
        fi
    else
        echo_green "gitlab runner already installed!"
    fi

    echo_green "Allow gitlab user for run docker..."

    if ! add_user_to_group "$username" "docker"; then
        return 1
    fi

    echo_green "Restart gitlab runner service..."

    if ! gitlab_prepare_runner_service "$CONST_GITLAB_SERVICE_NAME" "$username" "$not_ask"; then
        return 1
    fi

    if systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_green "Restart gitlab runner service..."
        if ! systemctl restart gitlab-runner.service; then
            echo_red "Cannot restart gitlab runner service!"
            return 1
        fi
    fi

    echo_green "gitlab runner installed!"
}

# shellcheck disable=SC2329
function phase_gitlab_help() {
    echo -n "
    Install and prepare gitlab runner.
    No Options.
"
}

# shellcheck disable=SC2329
function phase_gitlab_disable_env() {
    echo -n "DISABLE_GITLAB"
}

# End src/include/phase_80_gitlab.sh

# Start src/include/phase_81_gitlab_register.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["gitlab_register"]="81"

# shellcheck disable=SC2329
function phase_gitlab_register_run() {
    echo_green "Gitlab register runner..."
    if ! cmd_gitlab_register_runner_run "$@"; then
        return 1
    fi
    echo_green "Gitlab runner registered!"
    return 0
}

# shellcheck disable=SC2329
function phase_gitlab_register_help() {
    cmd_gitlab_register_runner_help
}

# shellcheck disable=SC2329
function phase_gitlab_register_disable_env() {
    echo -n "DISABLE_GITLAB_REGISTER_RUNNER"
}

# End src/include/phase_81_gitlab_register.sh

# Start src/include/phase_82_werf.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["werf"]="82"

# shellcheck disable=SC2329
function phase_werf_run() {
    echo_green "Install werf..."

    if command -v werf &> /dev/null; then
        echo_green "Werf already installed!"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local url="https://werf.io/install.sh"

    if ! download_script_and_run "$url" "$not_ask" "--ci"; then
        return 1
    fi

    echo_green "Werf installed!"
}

# shellcheck disable=SC2329
function phase_werf_help() {
    echo -n "
    Install Werf
      No options.
"
}

# shellcheck disable=SC2329
function phase_werf_disable_env() {
    echo -n "DISABLE_WERF"
}

# End src/include/phase_82_werf.sh

# Start src/include/phase_83_flint.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["flint"]="83"

# shellcheck disable=SC2329
function phase_flint_run() {
    echo_green "Install flint..."

    if command -v flint &> /dev/null; then
        echo "Flint already installed!"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local url="https://tuf.flint.flant.ru/install.sh"

    local script_args=(
        "--version"
        "2"
        "--channel"
        "stable"
    )

    if ! download_script_and_run "$url" "$not_ask" "${script_args[@]}"; then
        return 1
    fi

    echo_green "Flint installed!"
}

# shellcheck disable=SC2329
function phase_flint_help() {
    echo -n "
    Install flint.
      No options.
"
}

# shellcheck disable=SC2329
function phase_flint_disable_env() {
    echo -n "DISABLE_FLINT"
}

# End src/include/phase_83_flint.sh

# Start src/include/phase_99_aliases.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["aliases"]="99"

# shellcheck disable=SC2329
function phase_aliases_run() {
    echo_green "Add aliases..."

    local content=""
    content=$(cat <<EOF
alias h='history | grep -i'
alias psf='ps aux | grep -i'
EOF
    )

    echo "$content" > /etc/profile.d/099-additional-aliases.sh

    echo_green "Aliases added!"
}

# shellcheck disable=SC2329
function phase_aliases_help() {
    echo -n "
    Add aditional aliases
    No Options.
"
}

# shellcheck disable=SC2329
function phase_aliases_disable_env() {
    echo -n "DISABLE_ALIASES"
}

# End src/include/phase_99_aliases.sh

# Start src/main.sh

function phase_run_func() {
    local phase="$1"

    local phase_func="phase_${phase}_run"

    if ! declare -F "$phase_func" > /dev/null; then
        echo_red "Internal error: '$phase_func' func not declared for phase $phase!"
        return 1
    fi

    echo -n "$phase_func"
    return 0
}

# shellcheck disable=SC2120
function usage() {
     echo "
Usage: $bin_name [phase PHASE_FOR_RUN | cmd CMD_FOR_RUN] [args...]
  Init server.
  Global parameters
    --not-ask
      If passed will not ask user about actions.
      Env NOT_ASK=true for set.

    --config 'PATH'
      Path to config with envs to settings.
      Should be .env format
      Env CONFIG_PATH 
    
    -h|--help
      Show this message.
  
  If passed 'phase' as first arg and name of phase as second
  only run only one phase.
  Otherwise, run all phases. For disable some phase 
  you can use disable env variable (see phase params).  
  
  Phases for run in order:
"

    for p in "$@"; do
        local help_fun="phase_${p}_help"
        if ! declare -F "$help_fun" > /dev/null; then
            echo_red "Help function not found for phase $p"
            exit 1
        fi
        echo ""
        echo "  Phase $p"
        "$help_fun"
        echo "    $(disable_help "$p")"
    done

    if [[ "${#COMMANDS_LIST[@]}" == "0" ]]; then
        return 0
    fi

    echo ""

    echo "
  If passed 'cmd' as first argument and name os command as second
  will run command

  Commands available:
"
    for cm in "${COMMANDS_LIST[@]}"; do
        local cmd_help_fun="cmd_${cm}_help"
        if ! declare -F "$cmd_help_fun" > /dev/null; then
            echo_red "Help function not found for command $cm"
            exit 1
        fi
        echo ""
        echo "  Command $cm"
        "$cmd_help_fun"
    done
}

function run_passed_command() {
    local cmd_name="${1-}"
    
    local found=""
    for cmd in "${COMMANDS_LIST[@]}"; do
        if [[ "$cmd_name" == "$cmd" ]]; then
            found="true"
            break
        fi
    done

    if [[ "$found" != "true" ]]; then
        echo_red "Command '$cmd_name' not found!"
        return 1
    fi

    local run_func="cmd_${cmd_name}_run"

    if ! declare -F "$run_func" > /dev/null; then
        echo_red "Run function $run_func for command $cmd_name not found!"
        return 1
    fi

    shift

    if ! "$run_func" "$@"; then
        echo_red "Command $cmd_name failed" 
        return 1
    fi

    return 0
}

function main() {
    local -a not_ordered_phases=()

    for pi in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$pi" ]; then
            echo_red "Got empty phase name!"
            exit 1
        fi
        not_ordered_phases+=("${PHASES_WITH_INDEX[$pi]}:${pi}")
    done

    local -a phases_sorted=()
    readarray -t phases_sorted < <(printf '%s\n' "${not_ordered_phases[@]}" | sort)

    local -a phases=()
    for ps in "${phases_sorted[@]}"; do
        local phase_to_add="${ps#*:}"
        local func_err=""
        if ! func_err="$(phase_run_func "$phase_to_add")"; then
            echo_red "$func_err"
            exit 1
        fi 
        phases+=("$phase_to_add")
    done

    local -a help_flags=("-h" "--help")

    for ha in "${help_flags[@]}"; do 
        if arg_flag_is_set "$ha" "" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@"; then
            usage "${phases[@]}"
            exit 0
        fi
    done

    local not_ask=""
    not_ask="$(parse_not_ask "$@")" || true

    local config=""

    if ! config="$(extract_argument "--config" "CONFIG_PATH" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_red "Passed config is incorrect: $config"
        exit 1
    fi

    if [ -n "$config" ]; then
        echo_green "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a
    fi

    local got_phase_to_run=""

    case "${1-}" in
        "phase")
            got_phase_to_run="${2-}"

            if [ -z "$got_phase_to_run" ]; then
                usage "${phases[@]}"
                echo_red "Phase not provided"
                exit 1
            fi
        
            if ! [[ -v PHASES_WITH_INDEX["$got_phase_to_run"] ]]; then
                usage "${phases[@]}"
                echo_red "Not found phase $got_phase_to_run"
                exit 1
            fi

            shift
            shift
        ;;

        "cmd")
            local got_command_to_run="${2-}"
            if [ -z "$got_command_to_run" ]; then
                usage "${phases[@]}"
                echo_red "Command not provided"
                exit 1
            fi

            shift
            shift

            if ! run_passed_command "$got_command_to_run" "$@"; then
                exit 1
            fi

            exit 0
        ;;
    esac

    local -a phases_to_run=()

    if [ -z "$got_phase_to_run" ]; then
        for pp in "${phases[@]}"; do
            if phase_is_not_disabled "$pp"; then
                phases_to_run+=("$pp")
            else
                echo_yellow "Phase $pp is skipped!"
            fi
        done
    else
        phases_to_run=("$got_phase_to_run")
    fi

    if [[ "${#phases_to_run[@]}" == "0" ]]; then
        echo_red "No one phase to run found!"
        exit 1
    fi

    local old_hostname=""
    if ! old_hostname="$(hostnamectl hostname)"; then
         old_hostname="ERROR GET"
    fi

    echo_green "Have next phases for run: ${phases_to_run[*]}"
    if ! ask_user "Start init ${old_hostname} ?" "$not_ask"; then
        echo_red "Disallow start!"
        exit 1
    fi

    for ph in "${phases_to_run[@]}"; do
        local phase_run=""

        if ! phase_run="$(phase_run_func "$ph")"; then
            echo_red "$phase_run"
            exit 1
        fi 

        echo ""
        echo_green "Run phase ${ph} with func '$phase_run'..."

        if ! "$phase_run" "$@"; then
            echo_red "Phase $ph failed! Exit"
            exit 1
        fi
        
        echo_green "Phase ${ph} successed!"
        echo ""
    done

    local new_hostname=""
    if ! new_hostname="$(hostnamectl hostname)"; then
         new_hostname="ERROR GET"
    fi

    echo_green "Init server $old_hostname done! New hostname: $new_hostname"
    return 0
}

main "$@"
exit $?

# End src/main.sh

