#!/usr/bin/env bash

set -Eeuo pipefail

bin_name="$0"

declare -A PHASES_WITH_INDEX=()
declare -a COMMANDS_LIST=()

# Start src/include/01-base_echo.sh

function echo_red(){
    echo -e "\033[1;31m$1\033[0m" >&2
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m" >&2
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m" >&2
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
function validate_arg_ipv4_func() {
    local val="$1"
    local regexp='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if [[ "$val" =~ $regexp ]]; then
        echo -n "$val"
        return 0
    fi 

    echo -n "Incorrect IPv4 $val"
    return 1
}

# shellcheck disable=SC2329
function validate_arg_ipv4() {
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

    if ! validate_arg_ipv4_func "$val"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function validate_arg_ipv4_optional() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo -n ""
        return 0
    fi

    if [ -z "$val" ]; then
        echo "Empty arg val"
        return 1 
    fi

    if ! validate_arg_ipv4_func "$val"; then
        return 1
    fi

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

# shellcheck disable=SC2329
function ask_user_choice() {
    local prompt="$1"
    
    shift

    local answer=""

    read -p "${prompt}: " answer

    for to_check in "$@"; do
        if [[ "$answer" == "$to_check" ]]; then
            echo -n "$answer"
            return 0
        fi
    done

    echo_red "Incorrect answer '$answer'"

    return 1
}

# shellcheck disable=SC2329
function ask_user_raw() {
    local prompt="$1"
    local validator="${2-${CONST_NO_VALIDATE}}"
    
    local answer=""

    read -p "${prompt}: " answer

    if [[ "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$answer"
        return 0
    fi

    local res=""

    if ! res="$($validator "$answer" "$CONST_ARG_PASSED")"; then
        echo_red "Incorrect answer '$answer': $res"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function remove_begin_spaces() {
    local content="$1"
    while [[ "$content" == [[:space:]]* ]]; do
        content="${content#[[:space:]]}"
    done
    echo -n "$content"
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
    
    # prevent to breack output
    sleep 1

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

# Start src/include/base_jq.sh

# shellcheck disable=SC2329
function jq_get_key_or_empty() { 
    local raw_out="$1"
    local key="$2"
    local required="${3-false}"

    local val=""
    local exit_code="128"

    val="$(jq -er "$key" <<<"$raw_out")"
    exit_code="$?"

    case "$exit_code" in
        "0")
            echo -n "$val"
            return 0
        ;;

        "1")
            if [[ "$required" == "true" ]]; then
                echo "Key not found $key"
                return 1
            fi

            echo -n ""
            return 0
    esac

    echo "Cannot get json key $key"
    return 1
}

# End src/include/base_jq.sh

# Start src/include/base_pkg.sh

if [ -z "${SYS_PACKAGES_ENGINE:-}" ]; then
    export SYS_PACKAGES_ENGINE="apt"
fi

# shellcheck disable=SC2329
function apt_update() {
    if ! apt update; then 
        echo_red "Cannot run apt update!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apt_install() {
    if ! apt install -y "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apt_search() {
    if dpkg-query -s "$1" &> /dev/null; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function apt_remove() {
    if ! apt purge -y --auto-remove "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_update() {
    if ! apk update; then 
        echo_red "Cannot run apk update!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_install() {
    if ! apk add --no-cache "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_search() {
    if apk info -e "$1" &> /dev/null; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function apk_remove() {
    if ! apk del "$@"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function get_package_cmd() {
    local cmd_name="$1"
    case "$SYS_PACKAGES_ENGINE" in
        "apt")
            true
        ;;

        "apk")
            true
        ;;

        *)
            echo_red "SYS_PACKAGES_ENGINE '${SYS_PACKAGES_ENGINE}' incorrect"
            return 1
        ;;
    esac

    local res="${SYS_PACKAGES_ENGINE}_${cmd_name}"

    if ! declare -F "$res" > /dev/null; then
        echo_red "Internal error: '$res' func not declared!"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function install_packages() {
    echo_green "Install apt packages $* ..."

    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    local install_fun=""
    if ! install_fun="$(get_package_cmd install)"; then
        return 1
    fi

    if ! "$update_fun"; then 
        echo_red "Cannot run update indexes!"
        return 1
    fi

    if ! "$install_fun" "$@"; then
        echo_red "Cannot run apt install!"
        return 1
    fi

    echo_green "Packages $* installed!"
}

# shellcheck disable=SC2329
function check_packages_installed() {
    local search_fun=""
    if ! search_fun="$(get_package_cmd search)"; then
        return 1
    fi

    local all="true"
    while [[ $# -gt 0 ]]; do
        local name="$1"
        if ! "$search_fun" "$name"; then
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
    local search_fun=""
    if ! search_fun="$(get_package_cmd search)"; then
        return 1
    fi

    local remove_fun=""
    if ! remove_fun="$(get_package_cmd remove)"; then
        return 1
    fi

    local -a for_remove=()

    while [[ $# -gt 0 ]]; do
        local name="$1"
        if "$search_fun" "$name"; then
            for_remove+=("$name")
        fi
        shift
    done

    if [[ "${#for_remove[@]}" == "0" ]]; then
        echo_green "All passed packages already removed"
        return 0
    fi

    echo_green "Remove packages ${for_remove[*]}"
    
    if ! "$remove_fun" "${for_remove[@]}"; then
        echo_red "Some packages not removed!"
        return 1
    fi

    return 0
}

# End src/include/base_pkg.sh

# Start src/include/base_service.sh

export CONST_SYS_SERVICE_ENGINE_SYSTEMD="systemctl"
export CONST_SYS_SERVICE_ENGINE_INITD="service"

declare -A _SYS_SERVICE_ENGINES_MAP=()
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="true"
_SYS_SERVICE_ENGINES_MAP["$CONST_SYS_SERVICE_ENGINE_INITD"]="true"

if [ -z "${SYS_SERVICE_ENGINE:-}" ]; then
    export SYS_SERVICE_ENGINE="$CONST_SYS_SERVICE_ENGINE_SYSTEMD"
fi

# shellcheck disable=SC2329
function get_sys_service_engine() {
    if [[ -v _SYS_SERVICE_ENGINES_MAP["$SYS_SERVICE_ENGINE"] ]]; then
        echo -n "$SYS_SERVICE_ENGINE"
        return 0
    fi

    echo_red "SYS_SERVICE_ENGINE '${SYS_SERVICE_ENGINE}' incorrect"
    return 1
}

# End src/include/base_service.sh

# Start src/include/base_systemd.sh

# shellcheck disable=SC2329
function systemd_disable_all() {
    for srv in "$@"; do
        if ! systemctl is-active "$srv"; then
            continue
        fi

        echo_green "systemd service $srv is active. Disable..."
        if ! systemctl disable --now "$srv"; then
            echo_red "Cannot disable $srv"
            return 1
        fi

        if ! systemctl stop "$srv"; then
            echo_red "Cannot stop $srv"
            return 1
        fi
    done

    return 0
}

# End src/include/base_systemd.sh

# Start src/include/base_user.sh

export CONST_REMOVE_PASSWORD="true"
export CONST_SUDO_NO_PASS="true"

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
function get_user_home(){
    local name="$1"

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

    if [ -z "$user_home" ]; then
        echo_red "User home not foend for $name"
        return 1
    fi

    if [ ! -d "$user_home" ]; then
        echo_red "User home $user_home is not directory for $name"
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
    local no_password="${2-no}"
    local not_ask="${3-no}"

    if [ -z "$name" ]; then
        echo_red "user name did not pass"
        return 1
    fi

    local sudoers_str="$name    ALL=(ALL:ALL) ALL"
    if [[ "$no_password" == "$CONST_SUDO_NO_PASS" ]]; then
        sudoers_str="$name    ALL=(ALL) NOPASSWD: ALL"
    fi

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

    local user_home=""
    if ! user_home="$(get_user_home "$name")"; then 
        echo_red "$user_home"
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

# shellcheck disable=SC2329
function get_loginable_users() {
    local passwd_out=""
    if ! passwd_out="$(getent passwd)"; then
        echo_red "Failed to call getent for get loginable users"
        return 1
    fi

    local users_passwd_list=""
    if ! users_passwd_list="$(grep -E -v '(false|nologin)$' <<<"$passwd_out")"; then
        echo -n ""
        return 0
    fi

    local users_raw_list=""
    if ! users_raw_list="$(cut -d: -f1 <<<"$users_passwd_list")"; then
        echo_red "Failed to ectract users names loginable users"
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

    if [ -n "$errors" ]; then
        echo_red "$errors"
        return 1
    fi

    local executor="shell"
    if [ -n "${GITLAB_RUNNER_EXECUTOR-}" ]; then 
        executor="${GITLAB_RUNNER_EXECUTOR}"
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
        "--executor" 
        "$executor"
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
           GITLAB_RUNNER_URL       - url to register gitlab runner.
           GITLAB_RUNNER_TOKEN     - token to register runner
           GITLAB_RUNNER_DESC      - name or description of new runner
           GITLAB_RUNNER_EXECUTOR  - executor of runner. Default shell
         All parameters is required.
         Can be provided with env GITLAB_RUNNER_CONFIG
    Also you can provide envs without config.
"
}

# End src/include/cmd_gitlab_register.sh

# Start src/include/cmd_virtualbox_init_vm_itself.sh

COMMANDS_LIST+=("virtualbox_init_vm_itself")

# shellcheck disable=SC2329
function validate_arg_mac_address() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo -n "Not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty address"
        return 1 
    fi

    if [[ "$val" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        echo -n "${val,,}"
        return 0
    fi

    if [[ "$val" =~ ^([0-9A-Fa-f]{12})$ ]]; then
        local -a parts=()
        
        for (( i=0; i<${#val}; i+=2 )); do 
            parts+=("${val:i:2}"); 
        done
        
        local res=""
        IFS=":" res="${parts[*]}" 

        echo -n "${res,,}"	
        
        return 0
    fi

    echo -n "Invalid MAC address $val"
    return 1
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_itself_run() {
    if command -v vboxmanage &> /dev/null; then
        echo_red "vboxmanage executable found!"
        echo_red "Probably you run virtualbox_init_vm_itself command outside vm"
        echo_red "If you want to init vm from host, use virtualbox_init_vm"
        return 1
    fi

    echo_green "Init virtualbox vm..."

    local package="openssh-server"

    if ! check_packages_installed "$package"; then
        echo_green "Install sshd..."
        if ! install_packages "openssh-server"; then
            echo_red "SSHD not installed!"
            return 1
        fi
    fi

    local nat_mac=""

    if ! nat_mac="$(extract_argument "--virtualbox-nat-mac" "VIRTUALBOX_NAT_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_red "NAT MAC address: $nat_mac"
        return 1
    fi

    local static_mac=""

    if ! static_mac="$(extract_argument "--virtualbox-static-mac" "VIRTUALBOX_STATIC_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_red "Static MAC address: $static_mac"
        return 1
    fi

    local ip_static=""

    if ! ip_static="$(extract_argument "--virtualbox-static-ip" "VIRTUALBOX_STATIC_IP" "$CONST_NOT_FLAG" "validate_arg_ipv4" "$@")"; then
        echo_red "Static IP address: $ip_static"
        return 1
    fi

    if [[ "$nat_mac" == "$static_mac" ]]; then
        echo_red "NAT and STATIC MACs should be different"
        return 1
    fi

    local -a ip_parts=()
    IFS="." read -ra ip_parts <<< "$ip_static"

    local gateway="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.1"

    if [[ "$ip_static" == "$gateway" ]]; then
        echo_red "IP $ip_static should not gateway $gateway"
        return 1
    fi

    local ssh_key=""
    if ! ssh_key="$(extract_argument "--virtualbox-ssh-key" "VIRTUALBOX_SSH_KEY" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "SSH key: $$ssh_key"
        return 1
    fi

    if [ -n "$ssh_key" ]; then
        if [ ! -s "$ssh_key" ]; then
            ssh_key=""
        fi
    fi

    local remove_sudo_pass=""
    if ! remove_sudo_pass="$(extract_argument "--virtualbox-sudo-no-password" "VIRTUALBOX_SUDO_NO_PASSWORD" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "Remove sudo pass: $$remove_sudo_pass"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local -a users_to_initialize=()

    if [[ $remove_sudo_pass == "$CONST_FLAG_SET" || "$ssh_key" != "" ]]; then
        echo_green "Users should initialize. Get loginable users..."

        local users_raw_list=""
        if ! users_raw_list="$(get_loginable_users)"; then
            echo_red "Failed to get loginable users"
            return 1
        fi

        local -a users_list=()
        IFS=":" read -ra users_list <<< "$users_raw_list"
        
        for user_to_append in "${users_list[@]}"; do 
            if [[ "$user_to_append" == "root" ]]; then
                echo_green "Skip root user"
                continue
            fi

            local user_home=""
            if ! user_home="$(get_user_home "$user_to_append")"; then
                echo_yellow "Not found user home for $user_to_append Skip"
                continue
            fi

            if [[ $user_home == "/home"* ]]; then
                users_to_initialize+=("$user_to_append")
                continue
            fi

            echo_yellow "Found user $user_to_append but home $user_home is not in /home Skip"
        done
    fi

    if [[ "$ssh_key" != "" && "${#users_to_initialize[@]}" != "0" ]]; then
        for init_user in "${users_to_initialize[@]}"; do
            echo_green "Init ssh key $ssh_key for user $init_user"
            if ! add_pubkey_for_user "$init_user" "$ssh_key" "$not_ask"; then
                echo_red "Failed to initialize ssh key for $init_user"
            fi
        done
    fi

    if [[ $remove_sudo_pass == "$CONST_FLAG_SET" && "${#users_to_initialize[@]}" != "0" ]]; then
        for init_user_pass in "${users_to_initialize[@]}"; do
            echo_green "Remove sudo pass for user $init_user_pass"
            if ! add_user_to_sudoers "$init_user" "$CONST_SUDO_NO_PASS" "$not_ask"; then
                echo_red "Failed to remove sudo pass for $init_user"
            fi
        done
    fi

    echo_green "Got NAT mac: $nat_mac Static mac $static_mac IP $ip_static Gateway $gateway"

    # shellcheck disable=SC2155
    local config_tmp="$(mktemp)"

    if ! chmod 600 "$config_tmp"; then
        echo_red "Cannot chmod temp file for config"
        return 1
    fi

    if ! chown "root:root" "$config_tmp"; then
        echo_red "Cannot chown temp file for config"
        return 1
    fi

    local backup_netplan="/root/backup_netplans"

    echo_green "Move old netplan configs to $backup_netplan"

    if ! mkdir -p "$backup_netplan"; then
        echo_red "Cannot create old netplans backup dir $backup_netplan"
        return 1
    fi

    local netplan_dir="/etc/netplan"
    local target_file="${netplan_dir}/00-static.yaml"

    local -a backup_files=()
    local cur_backup_file=""
    while IFS= read -r -d '' cur_backup_file; do
        if [ -z "$cur_backup_file" ]; then
            continue
        fi

        if [[ "$cur_backup_file" == "$target_file" ]]; then
            continue
        fi

        backup_files+=("$cur_backup_file") 
    done < <(find "$netplan_dir" -name '*.yaml' -type f -print0)

    if [[ "${#backup_files[@]}" == "0" ]]; then
        echo_green "Nothing to backup"
    else
        for to_bkp in "${backup_files[@]}"; do
            if ! mv "$to_bkp" "$backup_netplan"; then
                echo_red "Cannot backup file $to_bkp"
                return 1
            fi
        done
    fi

        local content=""
    content=$(cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp6: true
      match:
        macaddress: $nat_mac
      set-name: enp0s3
      dhcp4-overrides:
        route-metric: 100
      dhcp6-overrides:
        route-metric: 100
    enp0s8:
      dhcp4: no
      dhcp6: no
      match:
        macaddress: $static_mac
      set-name: enp0s8
      addresses: [${ip_static}/24]
      routes:
        - to: default
          via: $gateway
          metric: 200
      nameservers:
        addresses: []

EOF
    )

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo "$content" > "$config_tmp"

    if ! replace_file "$config_tmp" "$target_file" "Change netplan config" "true" "$not_ask"; then
        return 1
    fi

    echo_green "Applly netplan..."

    if ! netplan apply; then
        echo_red "Netplan config does not applyed! Backups in $backup_netplan"
        return 1
    fi

    local remote_host="google.com"

    if command -v ping &> /dev/null; then
        echo_green "Netplan applyed! Verify internet connection with ping $remote_host"
        echo_green "Sleep 5 seconds before check..."
        sleep 5

        if ! ping -W 4 -c 4 "$remote_host"; then
            echo_red "Host $remote_host not accessable!"
            return 1
        fi
        echo_green "Internet connection success!" 
    else
        echo_yellow "Ping is not installed. Skip verify internet connection"
    fi

    if ask_user "Remove backup dir $backup_netplan ?" "$not_ask"; then
        if ! rm -rfv "$backup_netplan"; then
            echo_yellow "$backup_netplan not removed!"
        fi
    fi

    echo_green "Virtualbox vm initialized!"

    if [[ "${#users_to_initialize[@]}" != "0" ]]; then
        echo_green "You can try to verify ssh connection with:"
        for ssh_user in "${users_to_initialize[@]}"; do
            echo_green "ssh ${ssh_user}@$ip_static"
        done
    fi

    return 0
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_itself_help() {
    echo -n "
    Init virtualbox vm itself.
    This command SHOULD run in vm!
    Install sshd and init interfaces with static ip for vm.
    Options:
      --virtualbox-nat-mac MAC_ADDRESS
         MAC address for nat interface.
         MAC address can simple 12 len string without : separator
         or 17 len string with separators.
         Can be set with env VIRTUALBOX_NAT_MAC
      --virtualbox-static-mac MAC_ADDRESS
         MAC address for static interface.
         MAC address can simple 12 len string without : separator
         or 17 len string with separators.
         Can be set with env VIRTUALBOX_STATIC_MAC
      --virtualbox-static-ip IP_ADDRESS
         IP address for set to static interface.
         Can be set with env VIRTUALBOX_STATIC_IP
      --virtualbox-ssh-key PATH
         If passed and file not empty copy this file
         to all /home/\$USER/.ssh/authorized_keys
         Can be set with env VIRTUALBOX_SSH_KEY
      --virtualbox-sudo-no-password
         If passed remove sudo password for all users found in /home 
         Can be set with env VIRTUALBOX_SUDO_NO_PASSWORD
"
}

# End src/include/cmd_virtualbox_init_vm_itself.sh

# Start src/include/cmd_virtualbox_init_vm.sh

COMMANDS_LIST+=("virtualbox_init_vm")

# shellcheck disable=SC2329
function virtualbox_extract_not_quoted_value() { 
    local input="$1"

    if [ -z "$input" ]; then
        echo -n ""
        return 0
    fi

    local -a val_parts=()

    IFS="=" read -ra val_parts <<<"$input"

    if [[ "${#val_parts[@]}" != "2" ]]; then
        echo_red "incorrect input key/val $raw_key_val Have no 2 parts"
        return 1
    fi

    local res="${val_parts[1]#\"}"
    res="${res%\"}"

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_value_for_key_human() { 
    local raw_out="$1"
    local key="$2"
    local can_not_found="${3-false}"

    local raw_key_val=""
    if ! raw_key_val="$(grep --color=never "$key:" <<<"$raw_out")"; then
        if [[ "$can_not_found" == "true" ]]; then
            echo -n ""
            return 0
        fi
        echo_red "Cannot extract $key"
        return 1
    fi

    local -a val_parts=()

    IFS=":" read -ra val_parts <<<"$raw_key_val"

    if [[ "${#val_parts[@]}" != "2" ]]; then
        echo_red "incorrect input key/val $raw_key_val Have no 2 parts"
        return 1
    fi

    echo -n "$(remove_begin_spaces "${val_parts[1]}")"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_value_for_key() { 
    local raw_out="$1"
    local key="$2"
    local can_not_found="${3-false}"

    local raw_key_val=""
    if ! raw_key_val="$(grep --color=never "$key=" <<<"$raw_out")"; then
        if [[ "$can_not_found" == "true" ]]; then
            echo -n ""
            return 0
        fi
        echo_red "Cannot extract $key"
        return 1
    fi

    local res=""

    if ! res="$(virtualbox_extract_not_quoted_value "$raw_key_val")"; then
        echo_red "Cannot extract value for key ${key}: $res"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_mac_address() { 
    local raw_out="$1"
    local index="$2"

    local key="macaddress${index}"

    local mac=""
    if ! mac="$(virtualbox_extract_value_for_key "$raw_out" "$key")"; then
        echo_red "Cannot extract mac-addres for $key: $mac"
        return 1
    fi

    echo -n "$mac"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_octet() {
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

    if (( "$val" > 1 && "$val" < 254 )); then
        echo -n "$val"
        return 0
    fi

    echo "$val should be octet from 2 to 253"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_extract_host_iface() {
    local user_passed_ip="${1-}"
    local passed_iface="${2-}"
    local raw_out=""

    if ! raw_out="$(vboxmanage list hostonlyifs)"; then
        echo_red "Cannot get list hostonlyifs"
        return 1
    fi

    if [ -z "$raw_out" ]; then 
        echo_red "Hostonly adapters not found!"
        return 1
    fi

    raw_out="${raw_out//$'\n\n'/$'\1'}"

    local -a ifaces_raw_list=()
    IFS=$'\1' read -r -d '' -a ifaces_raw_list <<< "$raw_out"

    local -A ifaces=()
    local single_iface_name=""

    for iface_raw in "${ifaces_raw_list[@]}"; do
        if [ -z "$iface_raw" ]; then
            continue
        fi

        local name=""
        if ! name="$(virtualbox_extract_value_for_key_human "$iface_raw" "Name")"; then
            echo_red "Cannot extract hostonly interface name from $iface_raw :: $name"
            return 1
        fi

        local address=""
        if ! address="$(virtualbox_extract_value_for_key_human "$iface_raw" "IPAddress")"; then
            echo_red "Cannot extract hostonly interface name from $iface_raw :: $address"
            return 1
        fi

        single_iface_name="$name"

        ifaces["$name"]="$address"
    done

    local choiced_iface=""

    if [ -z "$passed_iface" ]; then
        case "${#ifaces[@]}" in
            "0")
                echo_red "Not found any hostonly interfaces"
                return 1
            ;;
            "1")
                choiced_iface="$single_iface_name"
                echo_green "Found single hostonly interface $choiced_iface with address ${ifaces[$choiced_iface]}" >&2
            ;;
            *)
                local -a indexes=()
                local cur_index=0
                local -A index_to_name=()
                for iface_name in "${!ifaces[@]}"; do
                    indexes+=("$cur_index")
                    index_to_name["$cur_index"]="$iface_name"
                    echo_green "[$cur_index] Found interface $iface_name with address ${ifaces[$iface_name]}" >&2
                    ((cur_index++))
                done

                local choiced_index="-1"
                if ! choiced_index="$(ask_user_choice "Enter interface number to attach" "${indexes[@]}")"; then
                    echo_red "Interface not choiced: $choiced_index"
                    return 1
                fi
                choiced_iface="${index_to_name[$choiced_index]}"
            ;;
        esac
    else
        if ! [[ -v ifaces["$passed_iface"] ]]; then
            echo_red "Not found interface $passed_iface"
            return 1
        fi
        choiced_iface="$passed_iface"
    fi

    local iface_address="${ifaces[$choiced_iface]}"

    local choiced_ip="$user_passed_ip"

    local -a gw_ip_parts=()
    IFS="." read -ra gw_ip_parts <<< "$iface_address"

    if [ -z "$choiced_ip" ]; then
        local octet=""
        if ! octet="$(ask_user_raw "Enter last octet number to assign address" "validate_arg_octet")"; then
            echo_red "Invalid inputed octet: $octet"
            return 1
        fi

        choiced_ip="${gw_ip_parts[0]}.${gw_ip_parts[1]}.${gw_ip_parts[2]}.$octet"
    else
        local -a choiced_ip_parts=()
        IFS="." read -ra choiced_ip_parts <<< "$choiced_ip"
        unset 'choiced_ip_parts[-1]'
        unset 'gw_ip_parts[-1]'
        if [[ "${gw_ip_parts[*]}" != "${choiced_ip_parts[*]}" ]]; then
            echo_red "Input IP $choiced_ip not in hostonly gw net $iface_address"
            return 1
        fi
    fi

    echo ""
    echo "Output;${choiced_iface};$choiced_ip"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_get_vm_info_json() {
    local vm_name="$1"
    local raw_out=""

    if ! raw_out="$(vboxmanage showvminfo "$vm_name" --machinereadable)"; then
        echo_red "Cannot get info for vm $vm_name"
        return 1
    fi

    local nics_index=1

    local res_json='
{
    "ifaces": {},
    "opticals": []
}'

    local nat_consumed=""
    local host_consumed=""

    while true; do
        local cur_nic_index="$nics_index"
        ((nics_index++))

        local nic_type_raw=""
        if ! nic_type_raw="$(grep --color=never "nic${cur_nic_index}=" <<<"$raw_out")"; then
            break
        fi

        local nic_type=""

        if ! nic_type="$(virtualbox_extract_not_quoted_value "$nic_type_raw")"; then
            echo_red "Cannot to extract nic type for index $cur_nic_index: $nic_type"
            return 1
        fi

        case "$nic_type" in
            "nat")
                if [[ "$nat_consumed" == "true" ]]; then
                    echo_red "NAT interface already consumed"
                    echo_red "$res_json"
                    return 1
                fi
                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_red "$mac"
                    return
                fi
                local nat_json=".ifaces += {\"nat\":{\"mac\":\"$mac\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$nat_json" <<<"$res_json")"; then
                    echo_red "Cannot append nat iface"
                    return 1
                fi
                nat_consumed="true"
            ;;

            "hostonly")
                if [[ "$host_consumed" == "true" ]]; then
                    echo_red "Hostonly interface already consumed"
                    echo_red "$res_json"
                    return 1
                fi

                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_red "$mac"
                    return
                fi

                local adapter=""
                if ! adapter="$(virtualbox_extract_value_for_key "$raw_out" "hostonlyadapter${cur_nic_index}")"; then
                    echo_red "Cannot extract hostonly adapter: $adapter"
                    return 1
                fi
                

                local host_json=".ifaces += {\"host\":{\"mac\":\"$mac\",\"adapter\":\"$adapter\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$host_json" <<<"$res_json")"; then
                    echo_red "Cannot append hostonly iface"
                    return 1
                fi
                host_consumed="true"
            ;;
            *)
                continue
            ;;
        esac
    done

    local ides_index=0
    local -a opticals=()
    while true; do
        local cur_ide_index="$ides_index"
        ((ides_index++))

        local minor=0

        local ide_type=""
        if ! ide_type="$(virtualbox_extract_value_for_key "$raw_out" "\"IDE-${cur_ide_index}-${minor}\"" "true")"; then
            echo_red "Cannot extract IDE-${cur_ide_index}-${minor} : $ide_type"
            return 1
        fi

        if [ -z "$ide_type" ]; then
            break
        fi

        if [ "$ide_type" != "none" ]; then
            opticals+=("${cur_ide_index}-${minor}")
        fi

        while true; do
            ((minor++))
            local ide_major=""
            if ! ide_major="$(virtualbox_extract_value_for_key "$raw_out" "\"IDE-${cur_ide_index}-${minor}\"" "true")"; then
                echo_red "Cannot extract IDE-${cur_ide_index}-${minor}: $ide_major"
                return 1
            fi
            
            if [ -z "$ide_major" ]; then
                break
            fi

            if [ "$ide_major" != "none" ]; then
                opticals+=("${cur_ide_index}-${minor}")
            fi
        done
    done

    for opt in "${opticals[@]}"; do
        local opt_json=".opticals += [\"$opt\"]"
        if ! res_json="$(jq "$opt_json" <<<"$res_json")"; then
            echo_red "Cannot append optical $opt"
            return 1
        fi
    done

    echo -n "$res_json"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_vm_is_running() {
    local vm_name="${1}"

    local all_vms=""
    if ! all_vms="$(vboxmanage list runningvms)"; then
        echo_red "Cannot get list running vms!"
        return 1
    fi

    if grep "$vm_name" <<<"$all_vms"; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function virtualbox_stop_vm() {
    local vm_name="$1"

    if ! virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    if ! vboxmanage controlvm "$vm_name" poweroff; then
        echo_red "Cannot stop vm $vm_name"
        return 1 
    fi

    local attempts=5

    for i in $(seq 1 $attempts); do
        if virtualbox_vm_is_running "$vm_name"; then
            echo_yellow "Waiting 5 seconds to stop vm $vm_name Attempt $i"
            sleep 5 
            continue
        fi
        return 0
    done

    if ! virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    echo_red "Vm $vm_name is not stopped after $attempts attempts"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_start_vm() {
    local vm_name="$1"

    if virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    local attempts=5

    for i in $(seq 1 $attempts); do
        if ! vboxmanage startvm "$vm_name"; then
            echo_yellow "Waiting 5 seconds to start vm $vm_name Attempt $1"
            sleep 5
            continue
        fi

        return 0 
    done

    if vboxmanage startvm "$vm_name"; then
        return 0
    fi

    echo_red "Vm $vm_name is not started after $attempts attempts"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_prepare_viso() {
    local vm_name="$1"
    local nat_mac="$2"
    local static_mac="$3"
    local ip_static="$4"
    local ssh_key="${5-}"

    local vm_name_sum=""
    if ! vm_name_sum=$(sha256sum <<<"$vm_name"); then
        echo_red "Cannot calculate sum from vm"
        return 1
    fi

    if ! vm_name_sum=$(cut -c 1-12 <<<"$vm_name_sum"); then
        echo_red "Cannot trim sum for vm"
        return 1
    fi

    local vm_dir="virtualbox/${vm_name_sum}"

    if ! mkdir -p "$vm_dir"; then
        echo_red "Cannot create tmp dir for vm $vm_name $vm_dir"
        return 1
    fi

    local bundle_file="${vm_dir}/init_bundle.sh"

    local -a files_to_viso=()

    # shellcheck disable=SC2154
    if ! cp "$bin_name" "$bundle_file"; then
        echo_red "Cannot copy init script $bin_name to $vm_dir"
        return 1
    fi

    files_to_viso+=("$bundle_file")

    local auth_keys_file="${vm_dir}/authorized_keys"

    if [ -n "$ssh_key" ] && [ -s "$ssh_key" ]; then
        if ! cp "$ssh_key" "$auth_keys_file"; then
            echo_red "Cannot copy ssh key $ssh_key to $vm_dir"
            return 1
        fi
    else
        echo -n "" > "$auth_keys_file"
    fi

    files_to_viso+=("$auth_keys_file")

    local vm_name_file="${vm_dir}/vmname.txt"

    echo "$vm_name" > "$vm_name_file"

    files_to_viso+=("$vm_name_file")

    local init_file="${vm_dir}/init.sh"

    # bash not correct handle shebang and set 
    # when write file! 
    {
        echo -n "#"
        echo '!/usr/bin/env bash'
        echo -n 'se'
        echo 't -Eeuo pipefail'
    } > "$init_file"

    cat <<EOF >> "$init_file"
run_dir=\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)
run_dir="\$(realpath "\$run_dir")"

bundle_file="\${run_dir}/init_bundle.sh"

"\$bundle_file" cmd virtualbox_init_vm_itself \\
  --virtualbox-nat-mac "$nat_mac" \\
  --virtualbox-static-mac "$static_mac" \\
  --virtualbox-static-ip "$ip_static" \\
  --virtualbox-ssh-key "\${run_dir}/authorized_keys" \\
  --virtualbox-sudo-no-password

if [[ \$? != "0" ]]; then
    echo "Failed!"
    exit 1
fi

echo "Success"
exit 0

EOF
    files_to_viso+=("$init_file")

    if ! chmod 755 "${vm_dir}/init.sh"; then
        echo_red "Cannot chmod ${vm_dir}/init.sh"
        return 1
    fi

    local viso_file="${vm_dir}/image.viso"

    local -a create_args=(
        "--name-setup" 
        "iso"
        "--iprt-iso-maker-file-marker-bourne-sh=$(uuidgen)"
        "--strict-attribs"
        "--volid=initvm"
        "-o"
        "$viso_file"
    )

    for v_file in "${files_to_viso[@]}"; do
        local base=""
        if ! base="$(basename "$v_file")"; then
            echo_red "Cannot get base for $v_file"
            return 1
        fi
        create_args+=("/${base}=${v_file}")
    done

    if ! vbox-img createiso "${create_args[@]}" >&2; then
        echo_red "Cannot create viso $viso_file"
        return 1 
    fi

    if ! viso_file="$(realpath "$viso_file")"; then
        echo_red "Cannot get real path for $viso_file"
        return 1
    fi

    echo -n "$viso_file"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_unmount_opticals() {
    local vm_name="$1"

    shift

    if [[ "$#" == 0 ]]; then
        echo_green "Nothing to unmount"
        return 0 
    fi

    for opt in "$@"; do
        local -a opt_dev=()
        IFS="-" read -ra opt_dev <<<"$opt"
        if [[ "${#opt_dev[@]}" != "2" ]]; then
            echo_red "Failed to parse optical $opt Should have 0-0 for example"
            return 1
        fi


        local port="${opt_dev[0]}"
        local device="${opt_dev[1]}"

        echo_green "Unmount IDE on $vm_name port $port device $device"

        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium none; then
            echo_red "Failed to unmount optical $opt"
            return 1
        fi
    done

    return 0
}


# shellcheck disable=SC2329
function virtualbox_unmount_cleanup_after_init() {
    local vm_name="$1"
    local viso_file="$2"

    local viso_real=""
    if ! viso_real="$(realpath "$viso_file")"; then
        echo_red "Cannot real path for $viso_file"
        return 1
    fi

    local cleanup_dir=""
    if ! cleanup_dir="$(dirname "$viso_real")"; then
        echo_red "Cannot get cleanup dir from $viso_real"
        return 1
    fi

    echo_green "Stop vm to unmount init opticals..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_red "Failed to stop vm?"
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_red "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local opticals_str=""
    if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
        echo_red "Cannot get opticals from vm info: $vm_info_json"
        return 1
    fi

    local -a opticals_to_unmount=()
    IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"

    echo_green "Unmount init opticals..."

    if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
        return 1
    fi

    if ask_user "Do you want to remove dir $cleanup_dir"; then
        if ! rm -rfv "$cleanup_dir"; then
            echo_red "Dir $cleanup_dir not removed!"
            return 1
        fi
    else
        echo_yellow "Disallow remove dir $cleanup_dir"
    fi

    echo_green "Start vm..."

    if ! virtualbox_start_vm "$vm_name"; then
        echo_red "Vm not started!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function virtualbox_mount_opticals() {
    local vm_name="$1"

    shift

    if [[ "$#" == 0 ]]; then
        echo_red "Nothing to mount"
        return 1 
    fi

    if [ "$#" -gt  4 ]; then
        echo_red "To many mounts should be <= 4"
        return 1 
    fi

    local port=0
    local device=0

    for iso in "$@"; do
        echo_green "Mount $iso to $vm_name port $port device $device"
        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium "$iso"; then
            echo_red "Failed mount $iso to $vm_name port $port device $device"
            return 1
        fi

        ((port++))
        ((device++))

        if ((device > 1)); then
            device=0
        fi
    done

    return 0
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_run() {
    if ! command -v vboxmanage &> /dev/null; then
        echo_red "vboxmanage executable not found!"
        echo_red "Probably you run virtualbox_init_vm command inside vm"
        echo_red "If you want to init vm from vm, use virtualbox_init_vm_itself"
        return 1
    fi 
    
    if ! command -v vbox-img &> /dev/null; then
        echo_red "vbox-img executable not found!"
        echo_red "Probably you run virtualbox_init_vm command inside vm"
        echo_red "If you want to init vm from vm, use virtualbox_init_vm_itself"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo_red "virtualbox_init_vm command require jq"
        echo_red "Please install jq"
        return 1
    fi

    local vm_name=""
    if ! vm_name="$(extract_argument "--virtualbox-vm-name" "VIRTUALBOX_VM_NAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_red "Vm name not passed: $vm_name"
        return 1
    fi

    local attach_address=""
    if ! attach_address="$(extract_argument "--virtualbox-attach-address" "VIRTUALBOX_ATTACH_ADDRESS" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "Attach address incorrect: $attach_address"
        return 1
    fi

    local ssh_key_file=""
    if ! ssh_key_file="$(extract_argument "--virtualbox-ssh-key" "VIRTUALBOX_SSH_KEY" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "SSH key file incorrect: $ssh_key_file"
        return 1
    fi

    local skip_vsio=""
    if ! skip_vsio="$(extract_argument "--virtualbox-skip-prepare-init-iso" "VIRTUALBOX_SKIP_PREPARE_INIT_ISO" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "Skip VSIO flag parse error"
        return 1
    fi

    if [ -n "$attach_address" ]; then
        if ! attach_address="$(validate_arg_ipv4 "$attach_address" "$CONST_ARG_PASSED")"; then
            echo_red "Attach address incorrect: $attach_address"
            return 1
        fi
    fi

    echo_green "Init virtualbox vm $vm_name ..."

    local all_vms=""
    if ! all_vms="$(vboxmanage list vms)"; then
        echo_red "Cannot get all vms!"
        return 1
    fi

    if ! grep -q "$vm_name" <<<"$all_vms"; then
        echo_red "Vm $vm_name not found!"
        echo_red "Have next vms:"
        echo "$all_vms"
        return 1
    fi

    echo_green "Stop vm $vm_name ..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_red "Cannot stop vm $vm_name!"
        return 1
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_red "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local nat_mac=""
    local nat_index=""
    local host_mac=""
    local host_adapter=""

    if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "false")"; then
        echo_red "Cannot extract NAT mac: $nat_mac"
        return 1
    fi

    if [ -z "$nat_mac" ]; then
        echo_yellow "NAT interface not found! Create..."

        local host_index=""
        if ! host_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.indx" "false")"; then
            echo_red "Cannot extract index for host iface"
            return 1
        fi
        
        if [ -n "$host_indx" ]; then
            nat_index="$(($host_index + 1))"
            echo_green "Found host interface with index ${host_index}. NAT interface will create with index $nat_index"
        else
            nat_index="1"
            echo_green "Host interface not found. NAT iface will create with index $nat_index"
        fi

        if ! vboxmanage modifyvm "$vm_name" "--nic$nat_index" nat; then
            echo_red "Cannot add NAT interface"
            return 1
        fi

        nat_index=""
        if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_red "Cannot get vm info after add NAT: $vm_info_json"
            return 1
        fi

        if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "true")"; then
            echo_red "Cannot extract NAT mac: $nat_mac"
            return 1
        fi
    fi

    if ! nat_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.indx" "true")"; then
        echo_red "Cannot extract NAT index: $nat_index"
        return 1
    fi

    if ! host_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.mac" "false")"; then
        echo_red "Cannot extract hostonly mac: $host_mac"
        return 1
    fi

    if [ -n "$host_mac" ]; then
        if ! host_adapter="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.adapter" "true")"; then
            echo_red "Cannot extract hostonly adapter: $host_adapter"
            return 1
        fi
        
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address" "$host_adapter")"; then
            echo_red "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_red "Cannot exctract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_red "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"
    else
        echo_green "Host interface not found for vm. Try to extract..."
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address")"; then
            echo_red "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_red "Cannot exctract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        echo "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_red "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"

        local iface_indx="$(($nat_index + 1))"

        echo_green "Attach $host_adapter with index $iface_indx ..."

        if ! vboxmanage modifyvm "$vm_name" "--nic$iface_indx" hostonly "--host-only-adapter$iface_indx" "$host_adapter" "--cable-connected${iface_indx}" on; then
            echo_red "Failed attach $host_adapter with index $iface_indx"
            return 1
        fi

        local vm_info_json_after_add=""

        if ! vm_info_json_after_add="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_red "Cannot get vm info: $vm_info_json_after_add"
            return 1
        fi

        if ! host_mac="$(jq_get_key_or_empty "$vm_info_json_after_add" ".ifaces.host.mac" "false")"; then
            echo_red "Cannot extract hostonly mac: $host_mac"
            return 1
        fi
    fi

    echo_green "Got next vm info:"
    echo_green "  NAT mac:          $nat_mac"
    echo_green "  Host adapter mac: $host_mac"
    echo_green "  Attach address:   $attach_address"

    if [[ "$skip_vsio" != "$CONST_FLAG_SET" ]]; then
        local opticals_str=""
        if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
            echo_red "Cannot get opticals from vm info: $vm_info_json"
            return 1
        fi

        local -a opticals_to_unmount=()
        IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"
        
        echo_green "Prepare vsio..."

        local viso_file=""
        if ! viso_file="$(virtualbox_prepare_viso "$vm_name" "$nat_mac" "$host_mac" "$attach_address" "$ssh_key_file")"; then
            echo_red "Cannot prepare viso: $viso_file"
            return 1
        fi

        echo_green "Unmount opticals '${opticals_to_unmount[*]}' ..."

        if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
            return 1
        fi

        echo_green "Mount init viso..."

        if ! virtualbox_mount_opticals "$vm_name" "$viso_file"; then
            return 1
        fi

        echo_green "Start vm..."

        if ! virtualbox_start_vm "$vm_name"; then
            return 1
        fi

        echo_green "Vm started and init viso mount"
        echo_green "Please run in vm for initialize:"
        echo_green "sudo -i"
        echo_green "mkdir -p /root/init && mount /dev/sr0 /root/init && /root/init/init.sh | tee /root/init.log"
        echo_green "After init please verify connection"

        if ask_user "Vm init and initialize? Do you want to cleanup?"; then
            if ! virtualbox_unmount_cleanup_after_init "$vm_name" "$viso_file"; then
                echo_yellow "^^^ Cleanup failed"
            fi
            echo_green "Virtualbox vm initialized!"
            return 0
        fi

        echo_yellow "Virtualbox vm initialized but not cleanuped!"
    fi

    return 0
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_help() {
    echo -n "
    Init virtualbox vm.
    This command SHOULD run on host!
    Find hostonly adapter in vm and add if not found.
    Find Hostonly adapter for connect, if have multiple,
    ask user for choice adapter. 
    Also get last octet for assign address and get
    interfaces mac's.
    Prepare virtual iso image with init scripts, mount it
    and start vm.
    After start vm you need mount sr0 interface and run
    init.sh script that called cmd virtualbox_init_vm_itself command
    with consumed params.
    Init script install sshd, prepare users (copy public keys for users
    and remove sudo passwords for users) and call netplan
    with init interfaces. After all unmount sr0
    This command waiting for user init vm and run cleanup
    (stop vm, remove init optical from vm and start vm).
    Options:
      --virtualbox-vm-name NAME
         Name for init vm.
         Can be set with env VIRTUALBOX_VM_NAME
      --virtualbox-attach-address IP_ADDRESS
         Full ipv4 address to set to hostonly interface.
         Optional. 
         If not passed get hostonly interface to connect 
         and get last octet for fill full address.
         If passed find hostonly interface to connect
         and check that address in subnet (script means
         that adapter has /24 network).
         Can be set with env VIRTUALBOX_ATTACH_ADDRESS
      --virtualbox-ssh-key PATH
         Path to ssh public key to set for all logable users,
         expected of root.
         Optional. 
         If not pass, prepare empty file for init viso.
         virtualbox_init_vm_itself checks that file exists and not empty.
         Can be set with env VIRTUALBOX_SSH_KEY
      --virtualbox-skip-prepare-init-iso
         If pass optical drive with init not preparead and mount
         Optional. 
         Can be set with env VIRTUALBOX_SKIP_PREPARE_INIT_ISO

"
}

# End src/include/cmd_virtualbox_init_vm.sh

# Start src/include/phase_01_base_pkgs.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["base_pkgs"]="01"

# shellcheck disable=SC2329
function phase_base_pkgs_run() {
    echo_green "Upgrade all..."

    if ! apt update; then
        echo_red "Cannot run apt update"
        return 1
    fi

    if ! apt upgrade -y; then
        echo_red "Cannot run apt upgrade"
        return 1
    fi

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

    if [ -n "$valid" ]; then
        local base=""
        if base="$(basename "$ssh_key")"; then
            if [[ "$base" != "authorized_keys" ]]; then
                valid="$valid not authorized_keys"
            else
                valid=""
            fi
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
    local -A users_sudo_no_pass=()
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

        local sudo_no_pass_env="ADD_USER_${cur_index}_SUDO_NO_PASS"
        # shellcheck disable=SC2155
        local sudo_no_pass="$(get_env_value_or_default "$sudo_no_pass_env" "false")"

        local ssh_env="ADD_USER_${cur_index}_SSH_KEY"
        # shellcheck disable=SC2155
        local ssh_key="$(get_env_value_or_default "$ssh_env" "")"

        users["$username"]="true"
        users_no_pass["$username"]="$no_pass"
        users_passwords["$username"]="$pass"
        users_sudo["$username"]="$should_sudo"
        users_sudo_no_pass["$username"]="$sudo_no_pass"
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
        users_sudo_no_pass["$arg_username"]="$arg_sudo_no_pass"
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
        local user_sudo_no_pass="${users_sudo_no_pass["$add_user"]}"
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
            if ! add_user_to_sudoers "$add_user" "$user_sudo_no_pass" "$not_ask"; then
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
          --name            - name of user. required
          --sudo            - if passed add user to sudo group and sudoers.
          --sudo-no-pass    - if passed remove ask sudo password for user.
          --password        - if passed use PASSWORD as password. If not passed 
                              and not use --remove-password ask run passwd as not interactive
          --remove-password - if passed remove password for user.
          --ssh-pub-key     - path to ssh public key to add for user (should suffix .pub) or autorised keys file
    You can use next envs for add users.
    every env should has prefix ADD_USER_\${INDEX}_ when INDEX index for user started from 0 
    Script can try to get env ADD_USER_\${INDEX}_NAME and if next index env is not found stop adding
    Envs:
      ADD_USER_\${INDEX}_NAME         - user name
      ADD_USER_\${INDEX}_SUDO         - if has '$CONST_SHOULD_SUDO' value add to sudo, othervise not add 
      ADD_USER_\${INDEX}_SUDO_NO_PASS - if has '$CONST_SUDO_NO_PASS' value add to sudo, othervise not add 
      ADD_USER_\${INDEX}_PASSWORD     - password for set
      ADD_USER_\${INDEX}_NO_PASSWORD  - if has '$CONST_REMOVE_PASSWORD' value - remove password
      ADD_USER_\${INDEX}_SSH_KEY      - path to ssh pub key (should suffix .pub) or autorised keys file
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

declare -A _SSH_RESTART_FUNC=()
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="sshd_systemd_restart"
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_INITD"]="sshd_initd_restart"

function sshd_systemd_restart() {
    if ! systemctl restart ssh.service; then
        return 1
    fi

    return 0
}

function sshd_initd_restart() {
    if ! service sshd restart; then
        return 1
    fi

    return 0
}

function sshd_restart() {
    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_red "Cannot resolve system service engine"
        return 1
    fi

    local restart_fun=""
    if [[ -v _SSH_RESTART_FUNC["$service_engine"] ]]; then
        restart_fun="${_SSH_RESTART_FUNC["$service_engine"]}"
    else
        echo_red "Restart sshd func not found for service engine '$service_engine'"
        return 1
    fi

    if ! declare -F "$restart_fun" > /dev/null; then
        echo_red "Internal error: '$restart_fun' func not declared!"
        return 1
    fi

    if ! "$restart_fun"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_fix_privilegies_separation() {
    local run_dir="/run/sshd"

    if ! mkdir -p "$run_dir"; then 
        echo_red "Cannot create $run_dir dir"
        return 1
    fi

    if ! chmod 0755 "$run_dir"; then
        echo_red "Cannot chmod $run_dir dir"
        return 1
    fi

    local tmpfiles_dir="/etc/tmpfiles.d/"

    if ! mkdir -p "$tmpfiles_dir"; then 
        echo_red "Cannot create $tmpfiles_dir dir"
        return 1
    fi

    echo "d /run/sshd 0755 root root" > "${tmpfiles_dir}/sshd.conf"

    echo_green "Restart sshd after fix privilegies separation..."
    if ! sshd_restart; then
        echo_red "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_green "Verify sshd config after fix privilegies separation..."
    if ! sshd -t; then
        echo_yellow "Test sshd config failed after fix privilegies separation. Sleep 5 seconds before next attempt"
        sleep 5
        
        if ! sshd -t; then
            echo_red "Test sshd config after fix privilegies separation after second attempt!"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_disable_systemd_socket() {
    echo_green "Enable sshd service..."
    if ! systemctl enable --now ssh.service; then
        echo_red "Cannot enable ssh.service"
        return 1
    fi

    echo_green "SSHD service enabled! Restart..."

    if ! sshd_restart; then
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

    echo_green "Create missing privilege separation directory..."
    if ! sshd_fix_privilegies_separation; then
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

    if ! sshd_restart; then
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

        if ! sshd_restart; then
            echo_red "!!! SSHD was not restarted !!!"
        fi

        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_run() {
    local port=""
    local bind_address=""

    if ! port="$(extract_argument "--sshd-port" "SSHD_PORT" "$CONST_NOT_FLAG" "validate_arg_number" "$@")"; then
        echo_red "Incorrect sshd port"
        return 1
    fi

    if ! bind_address="$(extract_argument "--sshd-bind-address" "SSHD_BIND_ADDRESS" "$CONST_NOT_FLAG" "validate_arg_ipv4_optional" "$@")"; then
        echo_red "Incorrect bind sshd address"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_green "Prepare sshd..."

    local base_cfgs_dir="/etc/ssh/sshd_config.d"

    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_red "Cannot resolve system service engine"
        return 1
    fi

    if [[ "$service_engine" == "$CONST_SYS_SERVICE_ENGINE_SYSTEMD" ]]; then
        if ! sshd_disable_systemd_socket; then
            return 1
        fi
    fi

    echo_green "Prepare sshd. Apply new port..."

    local port_setting="Port $port"
    local port_file="${base_cfgs_dir}/99_z_port.conf"

    if ! sshd_apply_setting "$port_setting" "$port_file"; then
        echo_red "Cannot apply sshd port setting '$port_setting'"
        return 1
    fi

    echo_green "Prepare sshd. New port apply!"
    echo_green "Please verify that ssh available on port $port"

    if ! ask_user "SSH available? Continue?" "$not_ask"; then
        echo_red "Disallow continue"
        return 1
    fi

    if [ -n "$bind_address" ]; then
        echo_green "Prepare sshd. Set bind address..."

        local bind_setting="ListenAddress $bind_address"
        local bind_file="${base_cfgs_dir}/99_z_bind.conf"

        if ! sshd_apply_setting "$bind_setting" "$bind_file"; then
            echo_red "Cannot apply sshd port setting '$bind_setting'"
            return 1
        fi

        echo_green "Prepare sshd. Bind address apply!"
        echo_green "Please verify that ssh available on port $port"

        if ! ask_user "SSH available? Continue?" "$not_ask"; then
            echo_red "Disallow continue"
            return 1
        fi
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
    echo_green "Please verify that ssh not available with root"

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
    echo_green "Please verify that ssh not available with password auth"
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
      --sshd-bind-address ADDRESS
         Bind sshd to passed address if passed.
         Can be provided with env SSHD_BIND_ADDRESS
         Optional.
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

# Start src/include/phase_10_atop.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["atop"]="10"

# shellcheck disable=SC2329
function phase_atop_run() {
    echo_green "Disable atop..."

    if ! systemd_disable_all "atop.service" "atop-rotate.timer" "atopacct.service"; then
        return 1
    fi

    echo_green "Atop disabled!"

    return 0 
}

# shellcheck disable=SC2329
function phase_atop_help() {
    echo -n "
    Disable atop services.
    No options. 
"
 }

# shellcheck disable=SC2329
function phase_atop_disable_env() {
    echo -n "DISABLE_ATOP"
}

# End src/include/phase_10_atop.sh

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

    local user_home=""
    if ! user_home="$(get_user_home "$username")"; then 
        echo_red "$user_home"
        return 1
    fi

    local bash_logout_file="${user_home}/.bash_logout"

    if [ -f "$bash_logout_file" ]; then
        echo_green "Remove $bash_logout_file ..."
        if ! delete_file "$bash_logout_file"; then
            return 1
        fi
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

