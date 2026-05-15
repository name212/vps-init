#!/usr/bin/env bash

set -Eeuo pipefail

bin_name="$0"

declare -A PHASES_WITH_INDEX=()

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
    arg_flag_is_set "--not-ask" "NOT_ASK" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@"
    return $?
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
        return 0
    fi

    if [ ! -f "$real" ]; then
        echo "$val is not file!"
        return 0
    fi

    if [ ! -s "$real" ]; then
        echo "$val is empty file!"
        return 0
    fi

    echo -n "$real"
    return 0
}

# End src/include/02-args.sh

# Start src/include/03-base_input.sh

# shellcheck disable=SC2329
function ask_user() {
    local prompt="$1"
    local not_ask="${2-no}"

    if [[ "$not_ask" == "$CONST_FLAG_SET" ]]; then
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

    echo_green "--- $title from $src ---"
    cat "$src"
    echo_green "--- End file ---"
    echo ""
    echo_green "--- Diff ---"
    diff "$src" "$dest" || true
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

    curl -fsSL "$url" -o "$dest"
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

# End src/include/base_pkg.sh

# Start src/include/base_user.sh

# shellcheck disable=SC2329
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

# shellcheck disable=SC2329
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

    return 0
}

# End src/include/base_user.sh

# Start src/include/phase_add_users.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["users"]="02"

# shellcheck disable=SC2329
function phase_users_run() {
    if [[ "${DISABLE_USERS-no}" == "true" ]]; then
        echo_yellow "Skip add users!"
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

# shellcheck disable=SC2329
function phase_users_disable_env() {
    echo -n "DISABLE_USERS"
}

# End src/include/phase_add_users.sh

# Start src/include/phase_aliases.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["aliases"]="99"

# shellcheck disable=SC2329
function phase_aliases_run() {
    if [[ "${DISABLE_ALIASES-no}" == "true" ]]; then
        echo_yellow "Skip add aliases!"
        return 0
    fi

    cat << EOF > /etc/profile.d/099-additional-aliases.sh
alias h='history | grep -i'
EOF
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

# End src/include/phase_aliases.sh

# Start src/include/phase_base_pkgs.sh

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
        "iputils-ping" 
        "htop" 
        "mc" 
        "curl" 
        "jq" 
        "yq"
        "libc-bin"
        "diffutils"
        # "git"
        "procps"
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

# End src/include/phase_base_pkgs.sh

# Start src/include/phase_change_hostname.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["hostname"]="10"

# shellcheck disable=SC2329
function phase_hostname_run() {
    if [[ "${DISABLE_HOSTNAME-no}" == "true" ]]; then
        echo_yellow "Skip change sshd!"
        return 0
    fi

    local new_hostname="${SET_HOSTNAME-}"
    if [ -z "$new_hostname" ]; then
        echo_red "New hostname not passed!"
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
        return 0
    fi

    if ! hostnamectl set-hostname "$new_hostname"; then
        echo_red "Cannot set hostname to $new_hostname!"
        return 1
    fi

    echo_green "Prepare hostname. Change /etc/hosts..."
    local tab=$'\t'

    {
        echo ""
        echo "# local for ${new_hostname}"
        echo "127.0.0.1${tab}${new_hostname}"
        echo ""
    } >> "/etc/hosts"

    echo_green "--- New /etc/hosts ---"
    cat "/etc/hosts"
    echo_green "--- End file ---"

    return 0
}

# shellcheck disable=SC2329
function phase_hostname_help() {
    echo "
    Change hostname
    Options:
      --hostname hostaname
        Set new hostname.
        Can be provided with env SET_HOSTNAME
"
}

# shellcheck disable=SC2329
function phase_hostname_disable_env() {
    echo -n "DISABLE_HOSTNAME"
}

# End src/include/phase_change_hostname.sh

# Start src/include/phase_docker.sh

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

# End src/include/phase_docker.sh

# Start src/include/phase_gitlab.sh

# shellcheck disable=SC2329
function prepare_gitlab_runner_service() {
    local service_name="$1"
    local username="$2"

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
        echo_green "Runner $runner_name already will run with user!"
        if ! systemctl daemon-reload; then
            echo_red "Cannot run daemon reload!"
            return 1
        fi
        return 0
    fi

    echo_green "Gitlab service probably has not user: ${exec_str}"

    if ! ask_user "Do you want to reinstall service?"; then
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
function install_gitlab_runner() {
    local not_ask="$1"

    echo_green "Install gitlab runner..."

    echo_green "Create user for runner..."

    local username="gitlab-runner"
    
    if ! add_user "$username"; then
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

    local service_name="gitlab-runner.service"

    if ! prepare_gitlab_runner_service "$service_name" "$username"; then
        return 1
    fi

    if systemctl is-active "$service_name"; then
        echo_green "Restart gitlab runner service..."
        if ! systemctl restart gitlab-runner.service; then
            echo_red "Cannot restart gitlab runner service!"
            return 1
        fi
    fi

    echo_green "gitlab runner installed!"
}

# shellcheck disable=SC2329
function register_gitlab_runner() {
    local runner_config="$1"

    if [ ! -f "$runner_config" ]; then
        echo_red "$runner_config file not exists!"
        return 1
    fi

    # shellcheck disable=SC2046
    export $(grep -v '^#' "$runner_config" | xargs -d '\n')

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

# End src/include/phase_gitlab.sh

# Start src/include/phase_sshd.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="03"

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
        echo_yellow "Change to new sshd port setting $setting"
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
    if [[ "${DISABLE_PREPARE_SSHD-no}" == "true" ]]; then
        echo_yellow "prepare sshd!"
        return 0
    fi

    local port="${SSHD_PORT-}"
    if [ -z "$port" ]; then
        echo_red "SSHD port not passed"
        return 1
    fi

    if ! [[ $port =~ ^[0-9]+$ ]]; then
        echo_red "SSHD port is not number"
        return 1
    fi

    echo_green "Prepare sshd..."

    local base_cfgs_dir="/etc/ssh/sshd_config.d"

    echo_green "Prepare sshd. Disable systemd socket..."

    if ! systemctl enable --now ssh.service; then
        echo_red "Cannot enable ssh.service"
        return 1
    fi

    if ! systemctl stop ssh.socket; then
        echo_red "Cannot stop ssh.socket"
        return 1
    fi

    if ! systemctl disable --now ssh.socket; then
        echo_red "Cannot disabe ssh.socket"
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

    if ! ask_user "SSH available? Continue?"; then
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

    if ! ask_user "SSH not available with root? Continue?"; then
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

    if ! ask_user "SSH passwor auth not available? Continue?"; then
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

# End src/include/phase_sshd.sh

# Start src/include/phase_werf.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["werf"]="98"

# shellcheck disable=SC2329
function phase_werf_run() {
    if [[ "${DISABLE_WERF-no}" == "true" ]]; then
        echo_yellow "Skip install werf!"
        return 0
    fi

    echo_green "Install werf..."

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    if command -v werf &> /dev/null; then
        echo_green "Werf already installed!"
        return 0
    fi

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

# End src/include/phase_werf.sh

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
Usage: $bin_name [--phase PHASE_FOR_RUN] [args...]
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
  
  If passed --phase only run only one phase.
  Otherwise, run all phases. For disable some phase 
  you can use disable env variable (see phase params).  
  
  Phases for run in order:
"

    for p in "$@"; do
        local help_fun="phase_${p}_help"
        if ! declare -F "$help_fun" > /dev/null; then
            echo_red "Help function not found for $p"
            exit 1
        fi
        echo ""
        echo "  Phase $p"
        "$help_fun"
        echo "    $(disable_help "$p")"
    done
}

function main() {
    local -a not_ordered_phases=()

    for p in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$p" ]; then
            echo_red "Got empty phase name!"
            exit 1
        fi
        not_ordered_phases+=("${PHASES_WITH_INDEX[$p]}:${p}")
    done

    local -a phases_sorted=()
    readarray -t phases_sorted < <(printf '%s\n' "${not_ordered_phases[@]}" | sort)

    local -a phases=()
    for p in "${phases_sorted[@]}"; do
        local phase_to_add="${p#*:}"
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

    local phase_to_run=""

    if [[ "$1" == "phase" ]]; then
        phase_to_run="$2"
        if ! [[ -v PHASES_WITH_INDEX["$phase_to_run"] ]]; then
            usage "${phases[@]}"
            echo_red "Not found phase $phase_to_run"
            exit 1
        fi

        shift
        shift
    fi

    local config=""

    if ! config="$(arg_flag_is_set "--config" "CONFIG_PATH" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_red "Passed config is incorrect: $config"
        exit 1
    fi

    if [ -n "$config" ]; then
        echo_green "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a
    fi

    local -a phases_to_run=()

    if [ -z "$phase_to_run" ]; then
        for p in "${phases[@]}"; do
            if phase_is_not_disabled "$p"; then
                phases_to_run+=("$p")
            else
                echo_yellow "Phase $p is skipped!"
            fi
        done
    else
        phases_to_run=("$phase_to_run")
    fi

    if [[ "${#phases_to_run[@]}" == "0" ]]; then
        echo_red "No one phase to run found!"
        exit 1
    fi

    for p in "${phases[@]}"; do
        local phase_run=""

        if ! phase_run="$(phase_run_func "$phase_to_add")"; then
            echo_red "$phase_run"
            exit 1
        fi 

        echo_green "Run phase ${p}..."

        if ! "$phase_run" "$@"; then
            echo_red "Phase $p failed! Exit"
            exit 1
        fi
        
        echo_green "Phase ${p} successed!"
    done

    return 0
}

main "$@"
exit $?

# End src/main.sh

