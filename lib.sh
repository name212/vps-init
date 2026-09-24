#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
bin_name="$0"

# shellcheck disable=SC2034
declare -A PHASES_WITH_INDEX=()
# shellcheck disable=SC2034
declare -a COMMANDS_LIST=()

# Start vps-init/src/include/01_base_echo.sh

# shellcheck disable=SC2034
CONST_NEW_LINE=$'\n'
# shellcheck disable=SC2034
CONST_COLOR_GREEN=$'\033[1;32m'
# shellcheck disable=SC2034
CONST_COLOR_YELLOW=$'\033[1;33m'
# shellcheck disable=SC2034
CONST_COLOR_RED=$'\033[1;31m'
# shellcheck disable=SC2034
CONST_COLOR_NO=$'\033[0m'

# shellcheck disable=SC2329
function echo_green (){
    echo -e "${CONST_COLOR_GREEN}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_yellow (){
    echo -e "${CONST_COLOR_YELLOW}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_red(){
    echo -e "${CONST_COLOR_RED}${1:-}${CONST_COLOR_NO}"
}

# shellcheck disable=SC2329
function echo_error(){
    echo_red "$1" >&2
}

# shellcheck disable=SC2329
function echo_info (){
    echo_green "$1" >&2
}

# shellcheck disable=SC2329
function echo_warn (){
    echo_yellow "$1" >&2
}

# End vps-init/src/include/01_base_echo.sh

# Start vps-init/src/include/02_args.sh

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
        echo "Can be disabled with set env ${env_name}=true"
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
        echo_error "Internal error: '$validator' func not declared!"
        return 1
    fi

    local prepared
    if ! prepared="$($validator "$val" "$arg_passed")"; then
        echo_error "Incorrect: $prepared"
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

# End vps-init/src/include/02_args.sh

# Start vps-init/src/include/03_base_input.sh

function prepare_prompt_str() {
    local prompt="${1:-No prompt}"
    local yes_no_out="${2:-}"
    local yes_no=""
    if [ -n "$yes_no_out" ]; then
        # shellcheck disable=SC2059
        yes_no="$(printf " \e${CONST_COLOR_GREEN}[y/n]\e${CONST_COLOR_NO}")"
    fi
    printf "> \e${CONST_COLOR_YELLOW}%s\e${CONST_COLOR_NO}${yes_no}: " "$prompt"
}

# shellcheck disable=SC2329
function ask_user() {
    local prompt="${1-:No prompt}"
    local not_ask="${2-no}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local answer=""

    # shellcheck disable=SC2162
    read -p "$(prepare_prompt_str "$prompt" "print_yn")" answer

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice() {
    local prompt="${1-:No prompt}"
    
    shift

    local answer=""

    # shellcheck disable=SC2162
    read -p "$(prepare_prompt_str "$prompt")" answer

    for to_check in "$@"; do
        if [[ "$answer" == "$to_check" ]]; then
            echo -n "$answer"
            return 0
        fi
    done

    echo_error "Incorrect answer '$answer'"

    return 1
}

# shellcheck disable=SC2329
function ask_user_raw() {
    local prompt="${1-:No prompt}"
    local validator="${2-${CONST_NO_VALIDATE}}"
    
    local answer=""

    # shellcheck disable=SC2162
    read -p "$(prepare_prompt_str "$prompt")" answer

    if [[ "$validator" == "$CONST_NO_VALIDATE" ]]; then
        echo -n "$answer"
        return 0
    fi

    local res=""

    if ! res="$($validator "$answer" "$CONST_ARG_PASSED")"; then
        echo_error "Incorrect answer '$answer': $res"
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

# End vps-init/src/include/03_base_input.sh

# Start vps-init/src/include/04_base_diff.sh

export CONST_OUT_DIFF_OR_HAS_DIFF="true"
export CONST_DIFF_ADD_ARGS=("--color=always")

# shellcheck disable=SC2329
function out_diff() {
    local diff_str="${1:-}"
    local src_str="${2:-}"
    local dest_str="${3:-}"
    local title="${4:-Unknown}"
    local should_out_diff="${5:-"$CONST_OUT_DIFF_OR_HAS_DIFF"}"
    local has_diff=""

    local diff_to_out=""
    local diff_action=""
    local diff_action_msg=""

    if [ -n "$diff_str" ]; then
        diff_action="echo_warn"
        diff_action_msg="--- Changes: ---"
        diff_to_out="$diff_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -n "$src_str" ] && [ -z "$dest_str" ]; then
        diff_action="echo_info"
        diff_action_msg="--- Add new: ---"
        diff_to_out="$src_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    elif [ -z "$src_str" ] && [ -n "$dest_str" ]; then
        diff_action="echo_error" 
        diff_action_msg="--- Remove old: ---"
        diff_to_out="$dest_str"
        has_diff="$CONST_OUT_DIFF_OR_HAS_DIFF"
    else
        diff_action="echo_info"
        diff_action_msg="--- No diff ---"
    fi

    if [[ "$should_out_diff" == "$CONST_OUT_DIFF_OR_HAS_DIFF" ]]; then
        echo_info "--- Diff for: $title ---"
        "$diff_action" "$diff_action_msg"
        if [ -n "$diff_to_out" ]; then
            echo "$diff_to_out"
        fi
        echo_info "--- End diff for $title ---"
    fi


    if [[ "$has_diff" == "$CONST_OUT_DIFF_OR_HAS_DIFF" ]]; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function calc_diff_str() {
    local src="${1:-}"
    local dst="${2:-}"
    local title="${3:-Unknown}"

    local diff_out=""
    local diff_ret="0"

    # shellcheck disable=SC2090
    if diff_out="$(diff "${CONST_DIFF_ADD_ARGS[@]}" <(echo "$dst") <(echo "$src"))"; then
        diff_ret="0"
    else
        diff_ret="$?"
    fi

    out_diff "$diff_out" "" "" "$title"
    return "$diff_ret"
}

# shellcheck disable=SC2329
function files_has_not_diff() {
    local src="${1:-}"
    local dest="${2:-}"
    local title="${3:-Unknown}"
    local should_out="${4:-"$CONST_OUT_DIFF_OR_HAS_DIFF"}"

    title="'${title}' from file '$src' to '$dest'"

    if [ -z "$src" ]; then
        echo_error "Source file not passed"
        return 255
    fi

    if [ -z "$dest" ]; then
        echo_error "Dest file not passed"
        return 255
    fi

    local diff_out=""

     if [ -f "$src" ] && [ ! -f "$dest" ]; then
        local src_str=""
        if ! src_str="$(cat "$src")"; then
            echo_error "Cannot read source '$src'"
            return 255
        fi

        out_diff "$diff_out" "$src_str" "" "$title" "$should_out"
        return $?
    fi

    if [ ! -f "$src" ] && [ -f "$dest" ]; then
        local dest_str=""
        if ! dest_str="$(cat "$dest")"; then
            echo_error "Cannot read dest '$dest'"
            return 255
        fi

        out_diff "$diff_out" "" "$dest_str" "$title" "$should_out"
        return $?
    fi

    local ret_diff="0"

    # shellcheck disable=SC2090
    if diff_out="$(diff "${CONST_DIFF_ADD_ARGS[@]}" "$dest" "$src")"; then
        diff_out=""
    else
        ret_diff="$?"
    fi

    out_diff "$diff_out" "" "" "$title" "$should_out"

    return "$ret_diff"
}

# End vps-init/src/include/04_base_diff.sh

# Start vps-init/src/include/06_base_jq.sh

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
                echo_error "Key not found $key"
                return 1
            fi

            echo -n ""
            return 0
    esac

    echo_error "Cannot get json key $key"
    return 1
}

# End vps-init/src/include/06_base_jq.sh

# Start vps-init/src/include/10_base_fs.sh

# shellcheck disable=SC2329
function delete_file() {
    if ! rm "$1"; then
        echo_error "$1 not deleted!"
        return 1
    fi

    echo_info "$1 deleted"
}

# shellcheck disable=SC2329
function temp_file_with_content() {
    local content="${1:-}"

    local content_tmp_file=""
    if ! content_tmp_file="$(mktemp)"; then
        echo_error "Cannot create temp file"
        return 1
    fi

    if [ -z "$content_tmp_file" ]; then
        echo_error "Cannot create temp file"
        return 1
    fi

    echo -n "$content" > "$content_tmp_file"

    echo -n "$content_tmp_file"

    return 0
}

# shellcheck disable=SC2329
function replace_file() {
    local src="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local remove_src="${4:-true}"
    local not_ask="${5:-false}"

    local ret_diff="0"

    if files_has_not_diff "$src" "$dest" "$title" "$CONST_OUT_DIFF_OR_HAS_DIFF"; then
        ret_diff="0"
    else
        ret_diff="$?"
    fi

    if [[ "$ret_diff" == "255" ]]; then
        echo_error "Internal diff error"
        return 1
    fi

    if [[ "$ret_diff" == "0" ]]; then
        echo_info "No diff. Skip"
        return 0
    fi
    
    # prevent to break output
    sleep 1

    if ! ask_user "$title You can replace $dest with $src ?" "$not_ask"; then
        if [[ "$remove_src" == "true" ]]; then
            echo_info "$title delete source $src"
            if ! rm "$src"; then
                echo_warn "$title source file $src not deleted!"
            fi
        fi
        echo_error "Disallow replace $dest"
        return 1
    fi

    if ! cp "$src" "$dest"; then
        echo_error "$title not replaced. Source $src not deleted"
        return 1
    fi

    if [[ "$remove_src" == "true" ]]; then
        echo_info "$title delete source $src"
        if ! rm "$src"; then
            echo_warn "$title source file $src not deleted!"
            return 0
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function sync_file_content() {
    local content="$1"
    local dest="$2"
    local title="${3-Unknown}"
    local not_ask="${4:-false}"

    if [ -z "$dest" ]; then
        echo_error "File for sync not passed"
        return 1
    fi

    local temp_file=""

    if ! temp_file="$(temp_file_with_content "$content")"; then
        echo_error "Cannot create temp file for content"
        return 1
    fi

    if ! replace_file "$temp_file" "$dest" "$title" "true" "$not_ask"; then
        echo_error "Cannot sync file '$dest'"
        return 1
    fi

    return 0
}

# End vps-init/src/include/10_base_fs.sh

# Start vps-init/src/include/11-base_download.sh

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

    echo_info "Download script $url to ${script_path}..."

    download_url "$url" "$script_path"

    chmod 700 "$script_path"

    # shellcheck disable=SC2154
    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        echo_info "Run script ${script_path} without ask..."
        "$script_path" "${script_args[@]}"
        return $?
    fi

    echo_info "If you do not output script (big file) now you can use 'less ${script_path}' before approve"

    if ask_user "Output $script_path ?"; then
        cat "$script_path"
    fi

    if ! ask_user "Run $script_path ?"; then
        echo_error "Disallow run $script_path"
        delete_file "$script_path" || true
        return 1
    fi

    if ! "$script_path" "${script_args[@]}"; then 
        echo_error "Run $script_path failed!"
        delete_file "$script_path" || true
        return 1
    fi

    delete_file "$script_path" || true
    return 0
}

# End vps-init/src/include/11-base_download.sh

# Start vps-init/src/include/20_base_user.sh

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

# End vps-init/src/include/20_base_user.sh

# Start vps-init/src/include/21_base_pkg.sh

# shellcheck disable=SC2034
export SYS_PACKAGES_ENGINE_APT="apt"
# shellcheck disable=SC2034
export SYS_PACKAGES_ENGINE_APK="apk"

if [ -z "${SYS_PACKAGES_ENGINE:-}" ]; then
    export SYS_PACKAGES_ENGINE="$SYS_PACKAGES_ENGINE_APT"
fi


# shellcheck disable=SC2329
function get_package_manager() {
    echo -n "$SYS_PACKAGES_ENGINE"
}


# shellcheck disable=SC2329
function apt_update() {
    if ! apt update; then 
        echo_error "Cannot run apt update!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apt_upgrade() {
    if ! apt upgrade -y; then 
        echo_error "Cannot run apt upgrade!"
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
function apk_upgrade() {
    if ! apk upgrade; then 
        echo_error "Cannot run apk upgrade!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function apk_update() {
    if ! apk update; then 
        echo_error "Cannot run apk update!"
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
        "$SYS_PACKAGES_ENGINE_APT")
            true
        ;;

        "$SYS_PACKAGES_ENGINE_APK")
            true
        ;;

        *)
            echo_error "SYS_PACKAGES_ENGINE '${SYS_PACKAGES_ENGINE}' incorrect"
            return 1
        ;;
    esac

    local res="${SYS_PACKAGES_ENGINE}_${cmd_name}"

    if ! declare -F "$res" > /dev/null; then
        echo_error "Internal error: '$res' func not declared!"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function upgrade_all_packages() {
    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    local upgrade_fun=""
    if ! upgrade_fun="$(get_package_cmd upgrade)"; then
        return 1
    fi

    if ! "$update_fun"; then
        echo_error "Cannot run update"
        return 1
    fi

    if ! "$upgrade_fun"; then
        echo_error "Cannot run apt upgrade"
        return 1
    fi
}

# shellcheck disable=SC2329
function install_packages() {
    echo_info "Install apt packages $* ..."

    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    local install_fun=""
    if ! install_fun="$(get_package_cmd install)"; then
        return 1
    fi

    if ! "$update_fun"; then 
        echo_error "Cannot run update indexes!"
        return 1
    fi

    if ! "$install_fun" "$@"; then
        echo_error "Cannot run apt install!"
        return 1
    fi

    echo_info "Packages $* installed!"
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
            echo_warn "$name not installed..."
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
        echo_info "All passed packages already removed"
        return 0
    fi

    echo_info "Remove packages ${for_remove[*]}"
    
    if ! "$remove_fun" "${for_remove[@]}"; then
        echo_error "Some packages not removed!"
        return 1
    fi

    return 0
}

# End vps-init/src/include/21_base_pkg.sh

# Start vps-init/src/include/22_base_service.sh

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

    echo_error "SYS_SERVICE_ENGINE '${SYS_SERVICE_ENGINE}' incorrect"
    return 1
}

# shellcheck disable=SC2329
function systemd_disable_all() {
    local srv="$1"

    if [ -z "$srv" ]; then
        echo_error "Service to disable not passed"
        return 1
    fi

    if ! systemctl is-active "$srv"; then
        return 0
    fi

    echo_info "systemd service $srv is active. Disable..."

    if ! systemctl disable --now "$srv"; then
        echo_error "Cannot disable $srv"
        return 1
    fi

    if ! systemctl stop "$srv"; then
        echo_error "Cannot stop $srv"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function service_disable_all() {
    local srv="$1"

    if [ -z "$srv" ]; then
        echo_error "Service to disable not passed"
        return 1
    fi

    if ! service "$srv" disable; then
        echo_error "Cannot disable $srv"
        return 1
    fi

    if ! service "$srv" stop; then
        echo_error "Cannot stop $srv"
        return 1
    fi
    return 0
}

# shellcheck disable=SC2329
function disable_and_stop_services() {
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    disable_fun="${service_engine}_disable_all"

    if ! declare -F "$disable_fun" > /dev/null; then
        echo_error "Internal error: '$disable_fun' func not declared!"
        return 1
    fi

    local -a not_disabled=()

    for srv in "$@"; do
        if ! "$disable_fun" "$srv"; then
            not_disabled+=("$srv")
        fi
    done

    if [[ "${#not_disabled[@]}" == 0 ]]; then
        return 0
    fi

    echo_error "Next services not disabled: ${not_disabled[*]}"
    return 1
}

# shellcheck disable=SC2329
function systemd_enable_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 1
    fi


    if ! systemctl enable --now "$srv"; then
        echo_error "Service '$srv' cannot enable"
        return 1
    fi
}


# shellcheck disable=SC2329
function service_enable_service() {
    local srv="${1:-}"

    if [ -z "$srv" ]; then
        echo_error "Service for enable not passed"
        return 1
    fi


    if ! service "$srv" enable; then
        echo_error "Service '$srv' cannot enable"
        return 1
    fi

    if ! service "$srv" restart; then
        echo_error "Service '$srv' cannot restarted"
        return 1
    fi

    return 0
}

# End vps-init/src/include/22_base_service.sh

# Start vps-init/src/include/cmd_gitlab_register.sh

COMMANDS_LIST+=("gitlab_register_runner")

export CONST_GITLAB_SERVICE_NAME="gitlab-runner.service"

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_run() {
    if ! command -v gitlab-runner &> /dev/null; then
        echo_error "gitlab runner is not installed!"
        echo_error "Please init server or install with --phase gitlab first."
        return 1
    fi

    if ! systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_error "gitlab runner service is not active!"
        echo_error "Please init server or install with --phase gitlab first."
        return 1
    fi

    local runner_config=""

    if ! runner_config="$(extract_argument "--gitlab-runner-config" "GITLAB_RUNNER_CONFIG" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_error "Gitlab runner config"
        return 1
    fi

    if [ -n "$runner_config" ]; then
        echo_info "Load runner config $runner_config"
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
        echo_error "$errors"
        return 1
    fi

    local executor="shell"
    if [ -n "${GITLAB_RUNNER_EXECUTOR-}" ]; then 
        executor="${GITLAB_RUNNER_EXECUTOR}"
    fi

    local runners=""
    if ! runners="$(gitlab-runner list -c /etc/gitlab-runner/config.toml)"; then
        echo_error "Cannot list runners!"
        return 1
    fi

    local runner_name="$GITLAB_RUNNER_DESC"

    if grep -q "$runner_name" <<<"$runners"; then
        echo_info "Runner $runner_name already registered!"
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
        echo_error "Cannot register runner ${runner_name}!"
        return 1
    fi
    
    echo_info "Runner ${runner_name} registered!"
}

# shellcheck disable=SC2329
function cmd_gitlab_register_runner_help() {
    echo -n "
    Register gitlab runner.
    Options:
      --gitlab-runner-config PATH
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

# End vps-init/src/include/cmd_gitlab_register.sh

# Start vps-init/src/include/cmd_virtualbox_init_vm_itself.sh

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
        echo_error "vboxmanage executable found!"
        echo_error "Probably you run virtualbox_init_vm_itself command outside vm"
        echo_error "If you want to init vm from host, use virtualbox_init_vm"
        return 1
    fi

    echo_info "Init virtualbox vm..."

    local package="openssh-server"

    if ! check_packages_installed "$package"; then
        echo_info "Install sshd..."
        if ! install_packages "openssh-server"; then
            echo_error "SSHD not installed!"
            return 1
        fi
    fi

    local nat_mac=""

    if ! nat_mac="$(extract_argument "--virtualbox-nat-mac" "VIRTUALBOX_NAT_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_error "NAT MAC address: $nat_mac"
        return 1
    fi

    local static_mac=""

    if ! static_mac="$(extract_argument "--virtualbox-static-mac" "VIRTUALBOX_STATIC_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_error "Static MAC address: $static_mac"
        return 1
    fi

    local ip_static=""

    if ! ip_static="$(extract_argument "--virtualbox-static-ip" "VIRTUALBOX_STATIC_IP" "$CONST_NOT_FLAG" "validate_arg_ipv4" "$@")"; then
        echo_error "Static IP address: $ip_static"
        return 1
    fi

    if [[ "$nat_mac" == "$static_mac" ]]; then
        echo_error "NAT and STATIC MACs should be different"
        return 1
    fi

    local -a ip_parts=()
    IFS="." read -ra ip_parts <<< "$ip_static"

    local gateway="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.1"

    if [[ "$ip_static" == "$gateway" ]]; then
        echo_error "IP $ip_static should not gateway $gateway"
        return 1
    fi

    local ssh_key=""
    if ! ssh_key="$(extract_argument "--virtualbox-ssh-key" "VIRTUALBOX_SSH_KEY" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "SSH key: $$ssh_key"
        return 1
    fi

    if [ -n "$ssh_key" ]; then
        if [ ! -s "$ssh_key" ]; then
            ssh_key=""
        fi
    fi

    local remove_sudo_pass=""
    if ! remove_sudo_pass="$(extract_argument "--virtualbox-sudo-no-password" "VIRTUALBOX_SUDO_NO_PASSWORD" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "Remove sudo pass: $$remove_sudo_pass"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local -a users_to_initialize=()

    if [[ $remove_sudo_pass == "$CONST_FLAG_SET" || "$ssh_key" != "" ]]; then
        echo_info "Users should initialize. Get loginable users..."

        local users_raw_list=""
        if ! users_raw_list="$(get_loginable_users)"; then
            echo_error "Failed to get loginable users"
            return 1
        fi

        local -a users_list=()
        IFS=":" read -ra users_list <<< "$users_raw_list"
        
        for user_to_append in "${users_list[@]}"; do 
            if [[ "$user_to_append" == "root" ]]; then
                echo_info "Skip root user"
                continue
            fi

            local user_home=""
            if ! user_home="$(get_user_home "$user_to_append")"; then
                echo_warn "Not found user home for $user_to_append Skip"
                continue
            fi

            if [[ $user_home == "/home"* ]]; then
                users_to_initialize+=("$user_to_append")
                continue
            fi

            echo_warn "Found user $user_to_append but home $user_home is not in /home Skip"
        done
    fi

    if [[ "$ssh_key" != "" && "${#users_to_initialize[@]}" != "0" ]]; then
        for init_user in "${users_to_initialize[@]}"; do
            echo_info "Init ssh key $ssh_key for user $init_user"
            if ! add_pubkey_for_user "$init_user" "$ssh_key" "$not_ask"; then
                echo_error "Failed to initialize ssh key for $init_user"
            fi
        done
    fi

    if [[ $remove_sudo_pass == "$CONST_FLAG_SET" && "${#users_to_initialize[@]}" != "0" ]]; then
        for init_user_pass in "${users_to_initialize[@]}"; do
            echo_info "Remove sudo pass for user $init_user_pass"
            if ! add_user_to_sudoers "$init_user" "$CONST_SUDO_NO_PASS" "$not_ask"; then
                echo_error "Failed to remove sudo pass for $init_user"
            fi
        done
    fi

    echo_info "Got NAT mac: $nat_mac Static mac $static_mac IP $ip_static Gateway $gateway"

    # shellcheck disable=SC2155
    local config_tmp="$(mktemp)"

    if ! chmod 600 "$config_tmp"; then
        echo_error "Cannot chmod temp file for config"
        return 1
    fi

    if ! chown "root:root" "$config_tmp"; then
        echo_error "Cannot chown temp file for config"
        return 1
    fi

    local backup_netplan="/root/backup_netplans"

    echo_info "Move old netplan configs to $backup_netplan"

    if ! mkdir -p "$backup_netplan"; then
        echo_error "Cannot create old netplans backup dir $backup_netplan"
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
        echo_info "Nothing to backup"
    else
        for to_bkp in "${backup_files[@]}"; do
            if ! mv "$to_bkp" "$backup_netplan"; then
                echo_error "Cannot backup file $to_bkp"
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

    echo_info "Apply netplan..."

    if ! netplan apply; then
        echo_error "Netplan config does not applied! Backups in $backup_netplan"
        return 1
    fi

    local remote_host="google.com"

    if command -v ping &> /dev/null; then
        echo_info "Netplan applied! Verify internet connection with ping $remote_host"
        echo_info "Sleep 5 seconds before check..."
        sleep 5

        if ! ping -W 4 -c 4 "$remote_host"; then
            echo_error "Host $remote_host not accessible!"
            return 1
        fi
        echo_info "Internet connection success!" 
    else
        echo_warn "Ping is not installed. Skip verify internet connection"
    fi

    if ask_user "Remove backup dir $backup_netplan ?" "$not_ask"; then
        if ! rm -rfv "$backup_netplan"; then
            echo_warn "$backup_netplan not removed!"
        fi
    fi

    echo_info "Virtualbox vm initialized!"

    if [[ "${#users_to_initialize[@]}" != "0" ]]; then
        echo_info "You can try to verify ssh connection with:"
        for ssh_user in "${users_to_initialize[@]}"; do
            echo_info "ssh ${ssh_user}@$ip_static"
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

# End vps-init/src/include/cmd_virtualbox_init_vm_itself.sh

# Start vps-init/src/include/cmd_virtualbox_init_vm.sh

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
        echo_error "incorrect input key/val $raw_key_val Have no 2 parts"
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
        echo_error "Cannot extract $key"
        return 1
    fi

    local -a val_parts=()

    IFS=":" read -ra val_parts <<<"$raw_key_val"

    if [[ "${#val_parts[@]}" != "2" ]]; then
        echo_error "incorrect input key/val $raw_key_val Have no 2 parts"
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
        echo_error "Cannot extract $key"
        return 1
    fi

    local res=""

    if ! res="$(virtualbox_extract_not_quoted_value "$raw_key_val")"; then
        echo_error "Cannot extract value for key ${key}: $res"
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
        echo_error "Cannot extract mac-address for $key: $mac"
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
        echo_error "Cannot get list hostonlyifs"
        return 1
    fi

    if [ -z "$raw_out" ]; then 
        echo_error "Hostonly adapters not found!"
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
            echo_error "Cannot extract hostonly interface name from $iface_raw :: $name"
            return 1
        fi

        local address=""
        if ! address="$(virtualbox_extract_value_for_key_human "$iface_raw" "IPAddress")"; then
            echo_error "Cannot extract hostonly interface name from $iface_raw :: $address"
            return 1
        fi

        single_iface_name="$name"

        ifaces["$name"]="$address"
    done

    local choiced_iface=""

    if [ -z "$passed_iface" ]; then
        case "${#ifaces[@]}" in
            "0")
                echo_error "Not found any hostonly interfaces"
                return 1
            ;;
            "1")
                choiced_iface="$single_iface_name"
                echo_info "Found single hostonly interface $choiced_iface with address ${ifaces[$choiced_iface]}" >&2
            ;;
            *)
                local -a indexes=()
                local cur_index=0
                local -A index_to_name=()
                for iface_name in "${!ifaces[@]}"; do
                    indexes+=("$cur_index")
                    index_to_name["$cur_index"]="$iface_name"
                    echo_info "[$cur_index] Found interface $iface_name with address ${ifaces[$iface_name]}" >&2
                    ((cur_index++))
                done

                local choiced_index="-1"
                if ! choiced_index="$(ask_user_choice "Enter interface number to attach" "${indexes[@]}")"; then
                    echo_error "Interface not choiced: $choiced_index"
                    return 1
                fi
                choiced_iface="${index_to_name[$choiced_index]}"
            ;;
        esac
    else
        if ! [[ -v ifaces["$passed_iface"] ]]; then
            echo_error "Not found interface $passed_iface"
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
            echo_error "Invalid input octet: $octet"
            return 1
        fi

        choiced_ip="${gw_ip_parts[0]}.${gw_ip_parts[1]}.${gw_ip_parts[2]}.$octet"
    else
        local -a choiced_ip_parts=()
        IFS="." read -ra choiced_ip_parts <<< "$choiced_ip"
        unset 'choiced_ip_parts[-1]'
        unset 'gw_ip_parts[-1]'
        if [[ "${gw_ip_parts[*]}" != "${choiced_ip_parts[*]}" ]]; then
            echo_error "Input IP $choiced_ip not in hostonly gw net $iface_address"
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
        echo_error "Cannot get info for vm $vm_name"
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
            echo_error "Cannot to extract nic type for index $cur_nic_index: $nic_type"
            return 1
        fi

        case "$nic_type" in
            "nat")
                if [[ "$nat_consumed" == "true" ]]; then
                    echo_error "NAT interface already consumed"
                    echo_error "$res_json"
                    return 1
                fi
                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_error "$mac"
                    return
                fi
                local nat_json=".ifaces += {\"nat\":{\"mac\":\"$mac\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$nat_json" <<<"$res_json")"; then
                    echo_error "Cannot append nat iface"
                    return 1
                fi
                nat_consumed="true"
            ;;

            "hostonly")
                if [[ "$host_consumed" == "true" ]]; then
                    echo_error "Hostonly interface already consumed"
                    echo_error "$res_json"
                    return 1
                fi

                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_error "$mac"
                    return
                fi

                local adapter=""
                if ! adapter="$(virtualbox_extract_value_for_key "$raw_out" "hostonlyadapter${cur_nic_index}")"; then
                    echo_error "Cannot extract hostonly adapter: $adapter"
                    return 1
                fi
                

                local host_json=".ifaces += {\"host\":{\"mac\":\"$mac\",\"adapter\":\"$adapter\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$host_json" <<<"$res_json")"; then
                    echo_error "Cannot append hostonly iface"
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
            echo_error "Cannot extract IDE-${cur_ide_index}-${minor} : $ide_type"
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
                echo_error "Cannot extract IDE-${cur_ide_index}-${minor}: $ide_major"
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
            echo_error "Cannot append optical $opt"
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
        echo_error "Cannot get list running vms!"
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
        echo_error "Cannot stop vm $vm_name"
        return 1 
    fi

    local attempts=5

    for i in $(seq 1 "$attempts"); do
        if virtualbox_vm_is_running "$vm_name"; then
            echo_warn "Waiting 5 seconds to stop vm $vm_name Attempt $i"
            sleep 5 
            continue
        fi
        return 0
    done

    if ! virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    echo_error "Vm $vm_name is not stopped after $attempts attempts"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_start_vm() {
    local vm_name="$1"

    if virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    local attempts=5

    for i in $(seq 1 "$attempts"); do
        if ! vboxmanage startvm "$vm_name"; then
            echo_warn "Waiting 5 seconds to start vm $vm_name Attempt $1"
            sleep 5
            continue
        fi

        return 0 
    done

    if vboxmanage startvm "$vm_name"; then
        return 0
    fi

    echo_error "Vm $vm_name is not started after $attempts attempts"
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
        echo_error "Cannot calculate sum from vm"
        return 1
    fi

    if ! vm_name_sum=$(cut -c 1-12 <<<"$vm_name_sum"); then
        echo_error "Cannot trim sum for vm"
        return 1
    fi

    local vm_dir="virtualbox/${vm_name_sum}"

    if ! mkdir -p "$vm_dir"; then
        echo_error "Cannot create tmp dir for vm $vm_name $vm_dir"
        return 1
    fi

    local bundle_file="${vm_dir}/init_bundle.sh"

    local -a files_to_viso=()

    # shellcheck disable=SC2154
    if ! cp "$bin_name" "$bundle_file"; then
        echo_error "Cannot copy init script $bin_name to $vm_dir"
        return 1
    fi

    files_to_viso+=("$bundle_file")

    local auth_keys_file="${vm_dir}/authorized_keys"

    if [ -n "$ssh_key" ] && [ -s "$ssh_key" ]; then
        if ! cp "$ssh_key" "$auth_keys_file"; then
            echo_error "Cannot copy ssh key $ssh_key to $vm_dir"
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
        echo_error "Cannot chmod ${vm_dir}/init.sh"
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
            echo_error "Cannot get base for $v_file"
            return 1
        fi
        create_args+=("/${base}=${v_file}")
    done

    if ! vbox-img createiso "${create_args[@]}" >&2; then
        echo_error "Cannot create viso $viso_file"
        return 1 
    fi

    if ! viso_file="$(realpath "$viso_file")"; then
        echo_error "Cannot get real path for $viso_file"
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
        echo_info "Nothing to unmount"
        return 0 
    fi

    for opt in "$@"; do
        local -a opt_dev=()
        IFS="-" read -ra opt_dev <<<"$opt"
        if [[ "${#opt_dev[@]}" != "2" ]]; then
            echo_error "Failed to parse optical $opt Should have 0-0 for example"
            return 1
        fi


        local port="${opt_dev[0]}"
        local device="${opt_dev[1]}"

        echo_info "Unmount IDE on $vm_name port $port device $device"

        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium none; then
            echo_error "Failed to unmount optical $opt"
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
        echo_error "Cannot real path for $viso_file"
        return 1
    fi

    local cleanup_dir=""
    if ! cleanup_dir="$(dirname "$viso_real")"; then
        echo_error "Cannot get cleanup dir from $viso_real"
        return 1
    fi

    echo_info "Stop vm to unmount init opticals..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_error "Failed to stop vm?"
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_error "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local opticals_str=""
    if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
        echo_error "Cannot get opticals from vm info"
        return 1
    fi

    local -a opticals_to_unmount=()
    IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"

    echo_info "Unmount init opticals..."

    if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
        return 1
    fi

    if ask_user "Do you want to remove dir $cleanup_dir"; then
        if ! rm -rfv "$cleanup_dir"; then
            echo_error "Dir $cleanup_dir not removed!"
            return 1
        fi
    else
        echo_warn "Disallow remove dir $cleanup_dir"
    fi

    echo_info "Start vm..."

    if ! virtualbox_start_vm "$vm_name"; then
        echo_error "Vm not started!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function virtualbox_mount_opticals() {
    local vm_name="$1"

    shift

    if [[ "$#" == 0 ]]; then
        echo_error "Nothing to mount"
        return 1 
    fi

    if [ "$#" -gt  4 ]; then
        echo_error "To many mounts should be <= 4"
        return 1 
    fi

    local port=0
    local device=0

    for iso in "$@"; do
        echo_info "Mount $iso to $vm_name port $port device $device"
        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium "$iso"; then
            echo_error "Failed mount $iso to $vm_name port $port device $device"
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
        echo_error "vboxmanage executable not found!"
        echo_error "Probably you run virtualbox_init_vm command inside vm"
        echo_error "If you want to init vm from vm, use virtualbox_init_vm_itself"
        return 1
    fi 
    
    if ! command -v jq &> /dev/null; then
        echo_error "virtualbox_init_vm command require jq"
        echo_error "Please install jq"
        return 1
    fi

    local vm_name=""
    if ! vm_name="$(extract_argument "--virtualbox-vm-name" "VIRTUALBOX_VM_NAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_error "Vm name not passed: $vm_name"
        return 1
    fi

    local attach_address=""
    if ! attach_address="$(extract_argument "--virtualbox-attach-address" "VIRTUALBOX_ATTACH_ADDRESS" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "Attach address incorrect: $attach_address"
        return 1
    fi

    local ssh_key_file=""
    if ! ssh_key_file="$(extract_argument "--virtualbox-ssh-key" "VIRTUALBOX_SSH_KEY" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "SSH key file incorrect: $ssh_key_file"
        return 1
    fi

    local skip_vsio=""
    if ! skip_vsio="$(extract_argument "--virtualbox-skip-prepare-init-iso" "VIRTUALBOX_SKIP_PREPARE_INIT_ISO" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "Skip VSIO flag parse error"
        return 1
    fi

    if [[ "$skip_vsio" != "$CONST_FLAG_SET" ]]; then
        if ! command -v vbox-img &> /dev/null; then
            echo_error "vbox-img executable not found!"
            echo_error "Probably you run virtualbox_init_vm command inside vm"
            echo_error "If you want to init vm from vm, use virtualbox_init_vm_itself"
            return 1
        fi
    fi

    if [ -n "$attach_address" ]; then
        if ! attach_address="$(validate_arg_ipv4 "$attach_address" "$CONST_ARG_PASSED")"; then
            echo_error "Attach address incorrect: $attach_address"
            return 1
        fi
    fi

    echo_info "Init virtualbox vm $vm_name ..."

    local all_vms=""
    if ! all_vms="$(vboxmanage list vms)"; then
        echo_error "Cannot get all vms!"
        return 1
    fi

    if ! grep -q "$vm_name" <<<"$all_vms"; then
        echo_error "Vm $vm_name not found!"
        echo_error "Have next vms:"
        echo "$all_vms"
        return 1
    fi

    echo_info "Stop vm $vm_name ..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_error "Cannot stop vm $vm_name!"
        return 1
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_error "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local nat_mac=""
    local nat_index=""
    local host_mac=""
    local host_adapter=""

    if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "false")"; then
        echo_error "Cannot extract NAT mac"
        return 1
    fi

    if [ -z "$nat_mac" ]; then
        echo_warn "NAT interface not found! Create..."

        local host_index=""
        if ! host_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.indx" "false")"; then
            echo_error "Cannot extract index for host iface"
            return 1
        fi
        
        if [ -n "$host_indx" ]; then
            # shellcheck disable=SC2004
            nat_index="$(($host_index + 1))"
            echo_info "Found host interface with index ${host_index}. NAT interface will create with index $nat_index"
        else
            nat_index="1"
            echo_info "Host interface not found. NAT iface will create with index $nat_index"
        fi

        if ! vboxmanage modifyvm "$vm_name" "--nic$nat_index" nat; then
            echo_error "Cannot add NAT interface"
            return 1
        fi

        nat_index=""
        if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_error "Cannot get vm info after add NAT"
            return 1
        fi

        if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "true")"; then
            echo_error "Cannot extract NAT mac"
            return 1
        fi
    fi

    if ! nat_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.indx" "true")"; then
        echo_error "Cannot extract NAT index"
        return 1
    fi

    if ! host_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.mac" "false")"; then
        echo_error "Cannot extract hostonly mac"
        return 1
    fi

    if [ -n "$host_mac" ]; then
        if ! host_adapter="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.adapter" "true")"; then
            echo_error "Cannot extract hostonly adapter"
            return 1
        fi
        
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address" "$host_adapter")"; then
            echo_error "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_error "Cannot extract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_error "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"
    else
        echo_info "Host interface not found for vm. Try to extract..."
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address")"; then
            echo_error "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_error "Cannot extract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        echo "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_error "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"

        # shellcheck disable=SC2004
        local iface_indx="$(($nat_index + 1))"

        echo_info "Attach $host_adapter with index $iface_indx ..."

        if ! vboxmanage modifyvm "$vm_name" "--nic$iface_indx" hostonly "--host-only-adapter$iface_indx" "$host_adapter" "--cable-connected${iface_indx}" on; then
            echo_error "Failed attach $host_adapter with index $iface_indx"
            return 1
        fi

        local vm_info_json_after_add=""

        if ! vm_info_json_after_add="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_error "Cannot get vm info: $vm_info_json_after_add"
            return 1
        fi

        if ! host_mac="$(jq_get_key_or_empty "$vm_info_json_after_add" ".ifaces.host.mac" "false")"; then
            echo_error "Cannot extract hostonly mac"
            return 1
        fi
    fi

    echo_green "Got next vm info:"
    echo_green "  NAT mac:          $nat_mac"
    echo_green "  Host adapter mac: $host_mac"
    echo_green "  Attach address:   $attach_address"

    export VIRTUALBOX_HOST_NET_ATTACHED_ADDRESS="$attach_address"

    if [[ "$skip_vsio" != "$CONST_FLAG_SET" ]]; then
        local opticals_str=""
        if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
            echo_error "Cannot get opticals from vm info"
            return 1
        fi

        local -a opticals_to_unmount=()
        IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"
        
        echo_info "Prepare vsio..."

        local viso_file=""
        if ! viso_file="$(virtualbox_prepare_viso "$vm_name" "$nat_mac" "$host_mac" "$attach_address" "$ssh_key_file")"; then
            echo_error "Cannot prepare viso: $viso_file"
            return 1
        fi

        echo_info "Unmount opticals '${opticals_to_unmount[*]}' ..."

        if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
            return 1
        fi

        echo_info "Mount init viso..."

        if ! virtualbox_mount_opticals "$vm_name" "$viso_file"; then
            return 1
        fi

        echo_info "Start vm..."

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

        echo_yellow "Virtualbox vm initialized but not cleaned!"
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
         If pass optical drive with init not prepared and mount
         Optional. 
         Can be set with env VIRTUALBOX_SKIP_PREPARE_INIT_ISO

"
}

# End vps-init/src/include/cmd_virtualbox_init_vm.sh

# Start vps-init/src/include/phase_01_upgrade_pkgs.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["upgrade_pkgs"]="01"

# shellcheck disable=SC2329
function phase_upgrade_pkgs_run() {
    echo_info "Upgrade packages..."

    if ! upgrade_all_packages; then
        echo_error "Packages not upgraded"
        return 1
    fi

    echo_info "All packages upgraded!"
}

# shellcheck disable=SC2329
function phase_upgrade_pkgs_help() {
    echo -n "
    Upgrade all packages before run.
    No options.
"
}

# shellcheck disable=SC2329
function phase_upgrade_pkgs_disable_env() {
    echo -n "DISABLE_UPGRADE_ALL"
}

# End vps-init/src/include/phase_01_upgrade_pkgs.sh

# Start vps-init/src/include/phase_02_base_pkgs.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["base_pkgs"]="02"

# shellcheck disable=SC2329
function phase_base_pkgs_run() {
    local update_fun=""
    if ! update_fun="$(get_package_cmd update)"; then
        return 1
    fi

    if ! "$update_fun"; then
        echo_error "Cannot run update"
        return 1
    fi

    echo_info "Install base packages..."

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
        echo_info "Base packages already installed!"
        return 0
    fi
    
    if ! install_packages "${packages[@]}"; then
        echo_error "Base packages not installed!"
        return 1
    fi

    echo_info "Base packages installed!"
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

# End vps-init/src/include/phase_02_base_pkgs.sh

# Start vps-init/src/include/phase_03_remove_upgrade.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_upgrade"]="03"

# shellcheck disable=SC2329
function phase_remove_upgrade_run() {
    echo_info "Remove unattended upgrades..."

    if ! remove_packages "unattended-upgrades"; then
        return 1 
    fi

    local -a timers=("apt-daily.timer" "apt-daily-upgrade.timer")

    echo_info "Stop and disable timers ${timers[*]} ..."
    
    if ! systemctl disable "${timers[@]}"; then 
        echo_error "Cannot disable timers"
        return 1
    fi

    if ! systemctl stop "${timers[@]}"; then 
        echo_error "Cannot stop timers"
        return 1
    fi

    echo_info "Unattended upgrades removed!"
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

# End vps-init/src/include/phase_03_remove_upgrade.sh

# Start vps-init/src/include/phase_04_add_users.sh

export CONST_SHOULD_SUDO="true"

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

    local cur_index=0

    local -A users=()
    local -A users_no_pass=()
    local -A users_passwords=()
    local -A users_sudo=()
    local -A users_sudo_no_pass=()
    local -A users_keys=()

    while true; do
        echo_info "Try to extract user from envs with index ${cur_index} ..."
        local username_env="ADD_USER_${cur_index}_NAME"
        # shellcheck disable=SC2155
        local username="$(get_env_value_or_default "$username_env" "")"
        if [ -z "$username" ]; then
            echo_info "No get value with index $cur_index Done getting users from envs"
            break
        fi

        if [[ -v users["$username"] ]]; then
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

        users["$username"]="true"
        users_no_pass["$username"]="$no_pass"
        users_passwords["$username"]="$pass"
        users_sudo["$username"]="$should_sudo"
        users_sudo_no_pass["$username"]="$sudo_no_pass"
        users_keys["$username"]="$ssh_key"

        ((cur_index++))
    done

    echo_info "Try to extract users from args..."
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

        if [[ -v users["$arg_username"] ]]; then
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

        users["$arg_username"]="true"
        users_no_pass["$arg_username"]="$arg_no_pass"
        users_passwords["$arg_username"]="$arg_pass"
        users_sudo["$arg_username"]="$arg_should_sudo"
        users_sudo_no_pass["$arg_username"]="$arg_sudo_no_pass"
        users_keys["$arg_username"]="$arg_ssh_key"

        ((cur_user_add_arg++))
    done

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

# shellcheck disable=SC2329
function phase_users_disable_env() {
    echo -n "DISABLE_USERS"
}

# End vps-init/src/include/phase_04_add_users.sh

# Start vps-init/src/include/phase_05_change_hostname.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["hostname"]="05"

# shellcheck disable=SC2329
function phase_hostname_run() {
    local new_hostname=""

    if ! new_hostname="$(extract_argument "--new-hostname" "NEW_HOSTNAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_error "New hostname: $new_hostname"
        return 1
    fi

    echo_info "Prepare hostname..."

    local cur_hostanme=""
    if ! cur_hostanme="$(hostnamectl hostname)"; then
        echo_error "Cannot get current host name!"
        return 1
    fi

    if [[ "$new_hostname" == "$cur_hostanme" ]]; then
        echo_info "Hostname already set to $new_hostname!"
    else
        if ! hostnamectl set-hostname "$new_hostname"; then
            echo_error "Cannot set hostname to $new_hostname!"
            return 1
        fi
    fi

    local hosts_file="/etc/hosts"
    local tab=$'\t'
    local hostname_hosts="127.0.1.1${tab}${new_hostname}"

    if grep -q "$hostname_hosts" "$hosts_file"; then
        echo_info "$new_hostname added to $hosts_file for alias to 127.0.1.1"
    else
        echo_info "Prepare hostname. Add new hostname for alias 127.0.1.1 to ${hosts_file} ..."

        {
            echo ""
            echo "# local for ${new_hostname}"
            echo "$hostname_hosts"
            echo ""
        } >> "$hosts_file"

        echo_info "--- New $hosts_file ---"
        cat "$hosts_file"
        echo_info "--- End file ---"
    fi

    echo_info "Hostname changed!"

    return 0
}

# shellcheck disable=SC2329
function phase_hostname_help() {
    echo "
    Change hostname
    Options:
      --new-hostname hostanme
        Set new hostname.
        Can be provided with env NEW_HOSTNAME
"
}

# shellcheck disable=SC2329
function phase_hostname_disable_env() {
    echo -n "DISABLE_HOSTNAME"
}

# End vps-init/src/include/phase_05_change_hostname.sh

# Start vps-init/src/include/phase_06_sshd.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["sshd"]="06"

# shellcheck disable=SC2034
CONST_BASE_SSHD_CONFIG="/etc/ssh/sshd_config.d"
# shellcheck disable=SC2034
CONST_LISTEN_FILE="${CONST_BASE_SSHD_CONFIG}/99_z_listen.conf"

# shellcheck disable=SC2034
declare -A _SSH_RESTART_FUNC=()
# shellcheck disable=SC2034
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_SYSTEMD"]="sshd_systemd_restart"
# shellcheck disable=SC2034
_SSH_RESTART_FUNC["$CONST_SYS_SERVICE_ENGINE_INITD"]="sshd_initd_restart"

# shellcheck disable=SC2329
function sshd_systemd_restart() {
    if ! systemctl restart ssh.service; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_initd_restart() {
    if ! service sshd restart; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_restart() {
    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    local restart_fun=""
    if [[ -v _SSH_RESTART_FUNC["$service_engine"] ]]; then
        restart_fun="${_SSH_RESTART_FUNC["$service_engine"]}"
    else
        echo_error "Restart sshd func not found for service engine '$service_engine'"
        return 1
    fi

    if ! declare -F "$restart_fun" > /dev/null; then
        echo_error "Internal error: '$restart_fun' func not declared!"
        return 1
    fi

    if ! "$restart_fun"; then
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_fix_privilege_separation() {
    local run_dir="/run/sshd"

    if ! mkdir -p "$run_dir"; then 
        echo_error "Cannot create $run_dir dir"
        return 1
    fi

    if ! chmod 0755 "$run_dir"; then
        echo_error "Cannot chmod $run_dir dir"
        return 1
    fi

    local tmpfiles_dir="/etc/tmpfiles.d/"

    if ! mkdir -p "$tmpfiles_dir"; then 
        echo_error "Cannot create $tmpfiles_dir dir"
        return 1
    fi

    echo "d /run/sshd 0755 root root" > "${tmpfiles_dir}/sshd.conf"

    echo_info "Restart sshd after fix privilege separation..."
    if ! sshd_restart; then
        echo_error "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_info "Verify sshd config after fix privilege separation..."
    if ! sshd -t; then
        echo_warn "Test sshd config failed after fix privilege separation. Sleep 5 seconds before next attempt"
        sleep 5
        
        if ! sshd -t; then
            echo_error "Test sshd config after fix privilege separation after second attempt!"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_disable_systemd_socket() {
    echo_info "Enable sshd service..."
    if ! systemctl enable --now ssh.service; then
        echo_error "Cannot enable ssh.service"
        return 1
    fi

    echo_info "SSHD service enabled! Restart..."

    if ! sshd_restart; then
        echo_error "!!! SSHD was not restarted !!!"
        return 1
    fi

    echo_info "Stop sshd systemd socket.."
    if ! systemctl stop ssh.socket; then
        echo_error "Cannot stop ssh.socket"
        return 1
    fi

    echo_info "Disable sshd systemd socket..."
    if ! systemctl disable --now ssh.socket; then
        echo_error "Cannot disable ssh.socket"
        return 1
    fi

    echo_info "Create missing privilege separation directory..."
    if ! sshd_fix_privilege_separation; then
        return 1 
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_full_path() {
    local full_p=""
    if ! full_p="$(which sshd)"; then
        echo_error "Cannot which sshd"
        return 1
    fi

    if [ -z "$full_p" ]; then
        echo_error "which sshd is empty"
        return 1
    fi

    echo -n "$full_p"
    return 0
}

# shellcheck disable=SC2329
function sshd_verify_and_restart() {
    local setting="${1,,}"

    local sshd_bin=""
    if ! sshd_bin="$(sshd_full_path)"; then
        echo_error "Cannot get full path of sshd"
        return 1
    fi

    if ! "$sshd_bin" -t; then
        echo_error "Test sshd config failed!"
        return 1 
    fi

    local conf_for_check=""
    if ! conf_for_check="$("$sshd_bin" -T)"; then
        echo_error "Cannot get sshd config from sshd!"
        return 1 
    fi

    if ! grep -qi "$setting" <<<"$conf_for_check"; then
        echo_error "Cannot found setting '$setting' in sshd config!"
        return 1 
    fi

    echo_info "SSHD config is valid! Restart..."

    if ! sshd_restart; then
        echo_error "!!! SSHD was not restarted !!!"
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

    if ! grep -qPzo "$setting" "$conf_file"; then
        echo_warn "Change to new sshd port setting to '$setting'"
        echo "$setting" > "$conf_file"
    fi

    if ! chmod 600 "$conf_file"; then
        echo_warn "Cannot change mode for config file $conf_file"
    else
        if ! chown "root:root" "$conf_file"; then
            echo_warn "Cannot change owner to root for config file $conf_file"
        fi
    fi

    if ! sshd_verify_and_restart "$setting"; then
        echo_warn "Remove config $conf_file file and restart..."
        if ! delete_file "$conf_file"; then
            echo_error "Cannot remove port file config $conf_file"
        fi

        if ! sshd_restart; then
            echo_error "!!! SSHD was not restarted !!!"
        fi

        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function sshd_add_bind_address() {
    local listen_address="${1:-}"
    local port="${2:-}"
    local not_ask="${3-no}"

    if [ -z "$listen_address" ]; then
        return 0    
    fi

    local listen_setting=""

    if [[ "$listen_address" == "0.0.0.0" || "$listen_address" == "::" ]]; then
        listen_setting="ListenAddress 0.0.0.0${CONST_NEW_LINE}ListenAddress ::${CONST_NEW_LINE}"
    elif [[ -f "$CONST_LISTEN_FILE" ]]; then
        if ! listen_setting="$(cat "$CONST_LISTEN_FILE")"; then
            echo_error "Cannot cat '$CONST_LISTEN_FILE'"
            return 1
        fi

        if grep -q "ListenAddress 0.0.0.0" <<<"$listen_setting"; then
            listen_setting=""
        fi 
        
        if grep -q "$listen_address" <<<"$listen_setting"; then
            echo_info "$listen_address' already exists in '$CONST_LISTEN_FILE'. Skip:"
            echo_info "$listen_setting"
            return 0
        else
            listen_setting="${listen_setting}${CONST_NEW_LINE}ListenAddress ${listen_address}${CONST_NEW_LINE}"
        fi
    else
        listen_setting="ListenAddress ${listen_address}${CONST_NEW_LINE}"
    fi

    if [ -z "$listen_setting" ]; then
        echo_error "Listen settings is empty"
        return 1
    fi

    local listen_setting_to_set=""
    if ! listen_setting_to_set="$(awk -F\; '{print $1|"sort -u"}' <<<"$listen_setting")"; then
        echo_error "Cannot sort listen settings"
        return 1
    fi

    if [ -z "$listen_setting_to_set" ]; then
        echo_error "Listen settings is empty after sort"
        return 1
    fi

    echo_info "Prepare sshd. Set listen settings:${CONST_NEW_LINE}${listen_setting_to_set}"

    if ! sshd_apply_setting "$listen_setting_to_set" "$CONST_LISTEN_FILE"; then
        echo_error "Cannot apply sshd listing setting:${CONST_NEW_LINE}${listen_setting_to_set}"
        return 1
    fi

    echo_info "Prepare sshd. Listen address applied!"
    cat "$CONST_LISTEN_FILE" || true
    echo_info "Please verify that ssh available"

    if ! ask_user "SSH available? Continue?" "$not_ask"; then
        echo_error "Disallow continue"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_sshd_run() {
    local port=""
    local bind_address=""

    if ! port="$(extract_argument "--sshd-port" "SSHD_PORT" "$CONST_NOT_FLAG" "validate_arg_number" "$@")"; then
        echo_error "Incorrect sshd port"
        return 1
    fi

    if ! bind_address="$(extract_argument "--sshd-listen-address" "SSHD_LISTEN_ADDRESS" "$CONST_NOT_FLAG" "validate_arg_ipv4_optional" "$@")"; then
        echo_error "Incorrect bind listen sshd address"
        return 1
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_info "Prepare sshd..."

    local service_engine=""
    if ! service_engine="$(get_sys_service_engine)"; then
        echo_error "Cannot resolve system service engine"
        return 1
    fi

    if [[ "$service_engine" == "$CONST_SYS_SERVICE_ENGINE_SYSTEMD" ]]; then
        if ! sshd_disable_systemd_socket; then
            return 1
        fi
    fi

    echo_info "Prepare sshd. Apply new port..."

    local port_setting="Port $port"
    local port_file="${CONST_BASE_SSHD_CONFIG}/99_z_port.conf"

    if ! sshd_apply_setting "$port_setting" "$port_file"; then
        echo_error "Cannot apply sshd port setting '$port_setting'"
        return 1
    fi

    echo_info "Prepare sshd. New port apply!"
    echo_info "Please verify that ssh available on port $port"

    if ! ask_user "SSH available? Continue?" "$not_ask"; then
        echo_error "Disallow continue"
        return 1
    fi

    if ! sshd_add_bind_address "$bind_address" "$port" "$not_ask"; then
        return 1
    fi

    echo_info "Prepare sshd. Disable root login..."

    local auth_present=""
    # shellcheck disable=SC2044
    for auth_file in $(find /home -name "authorized_keys"); do 
        if [ -s "$auth_file" ]; then
            echo_info "Found not empty authorized_keys $auth_file"
            auth_present="true"
        fi 
    done

    if [ -z "$auth_present" ]; then
        echo_error "Not found any non zero authorized_keys files. Cannot continue"
        return 1
    fi

    local root_setting="PermitRootLogin no"
    local root_file="${CONST_BASE_SSHD_CONFIG}/99_z_disable_root.conf"

    if ! sshd_apply_setting "$root_setting" "$root_file"; then
        echo_error "Cannot disable root login '$root_setting'"
        return 1
    fi

    echo_info "Prepare sshd. Root login disabled!"
    echo_info "Please verify that ssh not available with root"

    if ! ask_user "SSH not available with root? Continue?" "$not_ask"; then
        echo_error "Disallow continue"
        return 1
    fi

    echo_info "Prepare sshd. Disable password auth..."

    local pass_setting="PasswordAuthentication no"
    local pass_file="${CONST_BASE_SSHD_CONFIG}/99_z_disable_pass_auth.conf"

    if ! sshd_apply_setting "$pass_setting" "$pass_file"; then
        echo_error "Cannot apply sshd port setting '$pass_setting'"
        return 1
    fi

    echo_info "Prepare sshd. Password auth disabled!"
    echo_info "Please verify that ssh not available with password auth"
    echo_info "Can be verify with command:" 
    echo_info "ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no YOUR_USER@HOST"

    if ! ask_user "SSH password auth not available? Continue?" "$not_ask"; then
        echo_error "Disallow continue"
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
      --sshd-listen-address ADDRESS
         Bind sshd to passed address if passed.
         Can be provided with env SSHD_LISTEN_ADDRESS
         Optional.
"
}

# shellcheck disable=SC2329
function phase_sshd_disable_env() {
    echo -n "DISABLE_PREPARE_SSHD"
}

# End vps-init/src/include/phase_06_sshd.sh

# Start vps-init/src/include/phase_07_docker.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["docker"]="07"

# shellcheck disable=SC2329
function install_docker_via_apt() {
    local packages=(
        "docker-ce" 
        "docker-ce-cli" 
        "containerd.io" 
        "docker-buildx-plugin" 
        "docker-compose-plugin"
    )

    for a_pkg in "$@"; do
        if [ -n "$a_pkg" ]; then
            packages+=("$a_pkg")
        fi
    done

    if check_packages_installed "${packages[@]}"; then
        echo_info "Docker already installed!"
        return 0
    fi

    echo_info "Add Docker's official GPG key..."

    if ! install -m 0755 -d /etc/apt/keyrings; then
        echo_error "Keyrings not installed"
        return 0
    fi
   
    if ! download_url "https://download.docker.com/linux/ubuntu/gpg" "/etc/apt/keyrings/docker.asc"; then
        echo_error "GPG keys not downloaded"
        return 0
    fi

    if ! chmod a+r /etc/apt/keyrings/docker.asc; then
        echo_error "Cannot chmod GPG keys"
        return 1
    fi

    echo_info "Add the docker repository to apt sources..."

# shellcheck disable=SC1091
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(source /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    echo_info "Install docker packages..."

    if ! install_packages "${packages[@]}"; then
        echo_error "Docker not installed!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function install_docker_via_apk() {
    local packages=(
        "dockerd" 
        "docker" 
    )

    for a_pkg in "$@"; do
        if [ -n "$a_pkg" ]; then
            packages+=("$a_pkg")
        fi
    done

    if check_packages_installed "${packages[@]}"; then
        echo_info "Docker already installed!"
        return 0
    fi

    if ! install_packages "${packages[@]}"; then
        echo_error "Docker not installed!"
        return 1
    fi

    if ! service_enable_service "dockerd"; then
        echo_error "Cannot enable openssh"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_docker_run() {
    echo_info "Install docker..."

    local additional_packages_str=""
    if ! additional_packages_str="$(extract_argument "--docker-install-additional-packages" "DOCKER_ADDITIONAL_PACKAGES" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_error "Cannot parse additional packages"
        return 1
    fi

    local -a additional_pkgs=()
    if [ -n "$additional_packages_str" ]; then
        readarray -d ',' -t additional_pkgs <<<"$additional_packages_str"
    fi

    # shellcheck disable=SC2155
    # shellcheck disable=SC2034
    local pkg_manager="$(get_package_manager)"

    local install_fun=""

    if [[ "$pkg_manager" == "$SYS_PACKAGES_ENGINE_APT" ]]; then
        install_fun="install_docker_via_apt"
    elif [[ "$pkg_manager" == "$SYS_PACKAGES_ENGINE_APK" ]]; then
        install_fun="install_docker_via_apk"
    else
        echo_error "Incorrect package manager '$pkg_manager'"
        return 1
    fi

    if ! "$install_fun" "${additional_pkgs[@]}"; then
        echo_error "Docker is not installed via '$pkg_manager'!"
        return 1
    fi 

    echo_info "Docker installed!"
}

# shellcheck disable=SC2329
function phase_docker_help() {
    echo -n "
    Install docker
    Options
    --docker-install-additional-packages comma-separated-packages
        Install additional packages for docker (for example luci-app-dockerman for OpenWRT)
        Optional.
        Can be provided with env DOCKER_ADDITIONAL_PACKAGES
"
 }

# shellcheck disable=SC2329
function phase_docker_disable_env() {
    echo -n "DISABLE_DOCKER"
}

# End vps-init/src/include/phase_07_docker.sh

# Start vps-init/src/include/phase_10_atop.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["atop"]="10"

# shellcheck disable=SC2329
function phase_atop_run() {
    echo_info "Disable atop..."

    if ! disable_and_stop_services "atop.service" "atop-rotate.timer" "atopacct.service"; then
        return 1
    fi

    echo_info "Atop disabled!"

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

# End vps-init/src/include/phase_10_atop.sh

# Start vps-init/src/include/phase_80_gitlab.sh

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
            echo_error "Cannot get exec string for gitlab service"
            return 1
        fi
    else 
        echo_info "gitlab service not active!"
    fi

    if [ -z "$exec_str" ]; then
        echo_error "exec string for gitlab service is empty"
        return 1
    fi

    if grep -q "user $username" <<<"$exec_str"; then
        echo_info "Runner $service_name already will run with user!"
        if ! systemctl daemon-reload; then
            echo_error "Cannot run daemon reload!"
            return 1
        fi
        return 0
    fi

    echo_info "Gitlab service probably has not user: ${exec_str}"

    if ! ask_user "Do you want to reinstall service?" "$not_ask"; then
        echo_error "Disallow reinstall runner service!"
        return 1
    fi

    echo_info "Start reinstall gitlab service..."

    if ! sudo systemctl stop "$service_name"; then
        echo_error "Cannot stop gitlab runner service!"
        return 1
    fi

    echo_info "Start uninstall gitlab service..."

    if ! gitlab-runner uninstall; then
        echo_error "Cannot uninstall gitlab runner service!"
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

    echo_info "Start install gitlab service..."

    if ! gitlab-runner install "${install_args[@]}"; then
        echo_error "Cannot install gitlab runner service!"
        return 1
    fi

    echo_info "Reload systemd..."

    if ! systemctl daemon-reload; then
        echo_error "Cannot run daemon reload!"
        return 1
    fi

    echo_info "Start gitlab service..."

    if ! systemctl start "$service_name"; then
        echo_error "Cannot run gitlab service!"
        return 1
    fi

    echo_info "Enable gitlab service..."

    if ! systemctl enable "$service_name"; then
        echo_error "Cannot enable gitlab service!"
        return 1
    fi
    
    echo_info "Gitlab service reinstalled with new user!"
}

# shellcheck disable=SC2329
function phase_gitlab_run() {
    echo_info "Install gitlab runner..."

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo_info "Create user for runner..."

    local username="gitlab-runner"
    
    if ! add_user "$username" "$CONST_REMOVE_PASSWORD" "$not_ask" ""; then
        return 1
    fi

    local user_home=""
    if ! user_home="$(get_user_home "$username")"; then 
        return 1
    fi

    local bash_logout_file="${user_home}/.bash_logout"

    if [ -f "$bash_logout_file" ]; then
        echo_info "Remove $bash_logout_file ..."
        if ! delete_file "$bash_logout_file"; then
            return 1
        fi
    fi

    local package="gitlab-runner"

    if ! check_packages_installed "$package"; then
        echo_info "Prepare gitlab apt repository..."

        local url="https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh"

        if ! download_script_and_run "$url" "$not_ask"; then
            return 1
        fi

        echo_info "Install gitlab runner package ${package}..."

        if ! install_packages "$package"; then
            echo_error "gitlab runner not installed!"
            return 1
        fi
    else
        echo_info "gitlab runner already installed!"
    fi

    echo_info "Allow gitlab user for run docker..."

    if ! add_user_to_group "$username" "docker"; then
        return 1
    fi

    echo_info "Restart gitlab runner service..."

    if ! gitlab_prepare_runner_service "$CONST_GITLAB_SERVICE_NAME" "$username" "$not_ask"; then
        return 1
    fi

    if systemctl is-active "$CONST_GITLAB_SERVICE_NAME"; then
        echo_info "Restart gitlab runner service..."
        if ! systemctl restart gitlab-runner.service; then
            echo_error "Cannot restart gitlab runner service!"
            return 1
        fi
    fi

    echo_info "gitlab runner installed!"
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

# End vps-init/src/include/phase_80_gitlab.sh

# Start vps-init/src/include/phase_81_gitlab_register.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["gitlab_register"]="81"

# shellcheck disable=SC2329
function phase_gitlab_register_run() {
    echo_info "Gitlab register runner..."
    if ! cmd_gitlab_register_runner_run "$@"; then
        return 1
    fi
    echo_info "Gitlab runner registered!"
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

# End vps-init/src/include/phase_81_gitlab_register.sh

# Start vps-init/src/include/phase_82_werf.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["werf"]="82"

# shellcheck disable=SC2329
function phase_werf_run() {
    echo_info "Install werf..."

    if command -v werf &> /dev/null; then
        echo_info "Werf already installed!"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    local url="https://werf.io/install.sh"

    if ! download_script_and_run "$url" "$not_ask" "--ci"; then
        return 1
    fi

    echo_info "Werf installed!"
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

# End vps-init/src/include/phase_82_werf.sh

# Start vps-init/src/include/phase_98_aliases.sh

# shellcheck disable=SC2034
PHASES_WITH_INDEX["aliases"]="98"

# shellcheck disable=SC2329
function phase_aliases_run() {
    echo_info "Add aliases..."

    local content=""
    content=$(cat <<EOF
alias h='history | grep -i'
alias psf='ps aux | grep -i'
EOF
    )

    echo "$content" > /etc/profile.d/099-additional-aliases.sh

    echo_info "Aliases added!"
}

# shellcheck disable=SC2329
function phase_aliases_help() {
    echo -n "
    Add additional aliases
    No Options.
"
}

# shellcheck disable=SC2329
function phase_aliases_disable_env() {
    echo -n "DISABLE_ALIASES"
}

# End vps-init/src/include/phase_98_aliases.sh

# Start vps-init/src/include/phase_99_remove_passed_config.sh

export PROTECTED_PASSED_CONFIG_FILE=""

# shellcheck disable=SC2034
PHASES_WITH_INDEX["remove_passed_config"]="99"


function set_passed_config_file() {
    PROTECTED_PASSED_CONFIG_FILE="${1:-}"
}

# shellcheck disable=SC2329
function phase_remove_passed_config_run() {
    if [ -z "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_info "Config not passed. Skip remove."
        return 0
    fi

    if [ ! -f "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_warn "Passed config '$PROTECTED_PASSED_CONFIG_FILE' not file. Skip"
        return 0
    fi

    if ! rm -fv "$PROTECTED_PASSED_CONFIG_FILE"; then
        echo_error "Passed config '$PROTECTED_PASSED_CONFIG_FILE' not removed!"
        return 1
    fi

    if [ ! -f "$PROTECTED_PASSED_CONFIG_FILE" ]; then
        echo_info "$PROTECTED_PASSED_CONFIG_FILE was removed!"
    fi

    return 0
}

# shellcheck disable=SC2329
function phase_remove_passed_config_help() {
    echo -n "
    Remove passed config file via --config arg for security reason.
    No Options.
"
}

# shellcheck disable=SC2329
function phase_remove_passed_config_disable_env() {
    echo -n "DISABLE_CLEANUP_PASSED_CONFIG"
}

# End vps-init/src/include/phase_99_remove_passed_config.sh

