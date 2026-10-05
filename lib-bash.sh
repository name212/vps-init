#!/usr/bin/env bash

set -Eeuo pipefail

# Start vps-init/src/include/00_base_const_fn.sh

# shellcheck disable=SC2034
export CONST_SCRIPT_NAME="$0"

# shellcheck disable=SC2034
export CONST_SCRIPT_NAME_FULL="$CONST_SCRIPT_NAME"
if ! CONST_SCRIPT_NAME_FULL="$(realpath "$CONST_SCRIPT_NAME")"; then
    CONST_SCRIPT_NAME_FULL="$CONST_SCRIPT_NAME"
fi

# shellcheck disable=SC2155
export WORKING_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck disable=SC2034
export CONST_NEW_LINE=$'\n'


# shellcheck disable=SC2034
export CONST_FAIL_MAIN_EXIT_CODE_PREFIX="Main returns exit code:"

# shellcheck disable=SC2329
function __rand_str_n() {
    local num=${1:-1}

	local str=""
    if ! str="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$num")"; then
        true
    fi

    echo -n "$str"
    return 0
}

# shellcheck disable=SC2329
function __escape_new_line() {
	local val="${1:-}"
	echo -n "${val//${CONST_NEW_LINE}/\\n}"
	return 0
}

function get_original_script_name() {
    if [ -n "${SCRIPT_ORIGINAL_PATH:-}" ]; then
        echo -n "$SCRIPT_ORIGINAL_PATH"
        return 0
    fi

    if [ -n "${CONST_SCRIPT_NAME:-}" ]; then
        echo -n "$CONST_SCRIPT_NAME"
        return 0
    fi

    echo -n "unknown-name-script.sh"

    return 0
}

# End vps-init/src/include/00_base_const_fn.sh

# Start vps-init/src/include/01_base_echo.sh

# shellcheck disable=SC2329
function __is_debug_file_present(){
    if [ -n "${PRIVATE_SCRIPT_LOG_FILE:-}" ]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2034
export CONST_FORCE_DEBUG="__force_debug__"

# shellcheck disable=SC2034
export PRIVATE_SCRIPT_DEBUG_ENABLED=""
# shellcheck disable=SC2034
if ! __is_debug_file_present; then
    export PRIVATE_SCRIPT_LOG_FILE=""
fi

# shellcheck disable=SC2034
export CONST_LOG_LEVEL_DEBUG="debug"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_INFO="info"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_WARN="warn"
# shellcheck disable=SC2034
export CONST_LOG_LEVEL_ERROR="error"

# shellcheck disable=SC2034
export CONST_COLOR_GREEN=$'\033[1;32m'
# shellcheck disable=SC2034
export CONST_COLOR_YELLOW=$'\033[1;33m'
# shellcheck disable=SC2034
export CONST_COLOR_RED=$'\033[1;31m'
# shellcheck disable=SC2034
export CONST_COLOR_GRAY_LIGHT=$'\033[3;37m'
# shellcheck disable=SC2034
export CONST_COLOR_NO=$'\033[0m'

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
function __write_to_log_file () {
    local level="$1"
    local msg="$2"

    if [ -z "$PRIVATE_SCRIPT_LOG_FILE" ]; then
        return 0
    fi

    if [ ! -f "$PRIVATE_SCRIPT_LOG_FILE" ]; then
        return 0
    fi

    local dt=""
    if ! dt="$(date +'%Y-%m-%d %H:%M:%S')"; then
        dt="N/A-DATE"
    fi

    # shellcheck disable=SC2155
    local escaped_msg="$(__escape_new_line "$msg")"

    echo "[$dt] || [$level]: $escaped_msg" >> "$PRIVATE_SCRIPT_LOG_FILE" || true
}

# shellcheck disable=SC2329
function echo_error() {
    echo_red "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_ERROR" "$1" || true
}

# shellcheck disable=SC2329
function echo_warn () {
    echo_yellow "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_WARN" "$1" || true
}

# shellcheck disable=SC2329
function echo_info () {
    echo_green "$1" >&2
    __write_to_log_file "$CONST_LOG_LEVEL_INFO" "$1" || true
}

# shellcheck disable=SC2329
function is_log_level_debug_enabled() {
    local force="${1:-}"

    if [[ "$force" == "$CONST_FORCE_DEBUG" || "$PRIVATE_SCRIPT_DEBUG_ENABLED" == "$CONST_FORCE_DEBUG" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function echo_debug() {
    local msg="${1:-}"
    local force="${2:-}"

    if is_log_level_debug_enabled "$force"; then
        echo -e "${CONST_COLOR_GRAY_LIGHT}${msg}${CONST_COLOR_NO}" >&2
    fi

    __write_to_log_file "$CONST_LOG_LEVEL_DEBUG" "$1" || true
}

# shellcheck disable=SC2329
function __enable_debug_log () {
    local should_enabled="${1:-}"
    local val=""

    if [[ "$should_enabled" == "" || "$should_enabled" == "true" ]]; then
        echo_yellow "Debug logs output is enabled" >&2
        val="$CONST_FORCE_DEBUG"
    fi

    export PRIVATE_SCRIPT_DEBUG_ENABLED="$val"

    return 0
}

# shellcheck disable=SC2329
function __set_log_file () {
    local log_file="${1}"

    if __is_debug_file_present; then
       return 0 
    fi

    if [ -z "$log_file" ]; then
        echo_red "Log file is empty" >&2
        return 1
    fi

    if [ -d "$log_file" ]; then
        echo_red "Log file '$log_file' is directory" >&2
        return 1
    fi

    if ! touch "$log_file"; then
        echo_red "Log file '$log_file' not touch" >&2
        return 1
    fi

    export PRIVATE_SCRIPT_LOG_FILE="$log_file"

    local log_id=""
    if ! log_id="$(__rand_str_n "10")"; then
        log_id="N/A"
    fi

    __write_to_log_file "$CONST_LOG_LEVEL_INFO" "Start log [id=$log_id]" || true
    
    echo_debug "Log file: '$PRIVATE_SCRIPT_LOG_FILE'" >&2

    return 0
}

function print_debug_log_file(){
    if __is_debug_file_present; then
        echo_warn "Log file: '$PRIVATE_SCRIPT_LOG_FILE'"
    fi
}

# shellcheck disable=SC2329
function __tee_log_command_out() {
    local level="$1"

    shift

    if [[ "${#@}" == 0 ]]; then
        echo_warn "Command to tee out not found"
        return 0
    fi

    local cmd_run="$1"
    shift

    local output=""
    local ret_code="0"

    if ! output="$("$cmd_run" "$@" 2>&1)"; then
        ret_code="$?"
    fi

    if [[ "$ret_code" != "0" ]]; then
        echo_warn "'$cmd_run'... Returns error with ret code '$ret_code'"
    fi

    echo "$output" || true

    __write_to_log_file "$level" "$output" || true

    return 0
}

# shellcheck disable=SC2329
function tee_log_command_out_force() {
    __tee_log_command_out "$CONST_LOG_LEVEL_DEBUG" "$@"
    return 0
}

# shellcheck disable=SC2329
function tee_log_command_out() {
    if ! is_log_level_debug_enabled ""; then
        return 0
    fi

    __tee_log_command_out "$CONST_LOG_LEVEL_DEBUG" "$@"
    return 0
}

# End vps-init/src/include/01_base_echo.sh

# Start vps-init/src/include/02_base_system_01_bash_01_base.sh

# shellcheck disable=SC2329
function is_function_declared() {
    local fun="${1:-}"

    if [ -z "$fun" ]; then
        echo_error "Function is not passed"
        return 1
    fi

    if ! declare -F "$fun" > /dev/null; then
        echo_error "Function '$fun' is not declared"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function trap_all() {
    local fn="${1:-}"
    
    if [ -z "$fn" ]; then
        return 0
    fi

    if ! is_function_declared "$fn"; then
        echo_error "Function '$fn' is not declared for trap"
    fi

    # shellcheck disable=SC2086
    trap $fn EXIT
    # shellcheck disable=SC2086
    trap $fn SIGINT
    # shellcheck disable=SC2086
    trap $fn SIGTERM

    echo_debug "Set trap function '$fn' for EXIT SIGINT SIGTERM"
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

# End vps-init/src/include/02_base_system_01_bash_01_base.sh

# Start vps-init/src/include/02_base_system_01_bash_02_shebang.sh

# Use should only sh support only function here
# because this file can be imported standalone

# shellcheck disable=SC2034
export CONST_SCRIPT_RAN_WITH_NEW_SHEBANG_VAL="__re_ren_with_new_shebang__"

# shellcheck disable=SC2329
get_shebang_header() {
    # bash not correct handle shebang and set 
    # when write file! 
    printf "#"
    printf '!/usr/bin/env bash\n\n'
    printf 'se'
    printf 't -Eeuo pipefail\n\n'
    return 0
}

# shellcheck disable=SC2329
write_shebang_header() {
    get_shebang_header > "$1"
}

# shellcheck disable=SC2329
rerun_script_with_new_shebang() {
    if [ "${SCRIPT_RAN_WITH_NEW_SHEBANG:-}" = "$CONST_SCRIPT_RAN_WITH_NEW_SHEBANG_VAL" ]; then
        return 255
    fi

    __echo_red_shebang(){
        printf "\033[1;31m%s\033[0m\n" "${1:-}" >&2
    }

    __script_path_shebang="${1:-}"

    if [ -z "$__script_path_shebang" ]; then
        __echo_red_shebang "Script path is empty"
        return 1
    fi

    if [ ! -s "$__script_path_shebang" ]; then
        __echo_red_shebang "Script '$__script_path_shebang' not found or empty"
        return 1
    fi

    shift

    if ! __pwd_shebang_script="$(pwd)"; then
        __echo_red_shebang "Cannot run pwd"
        return 1
    fi

    export SCRIPT_RAN_WITH_NEW_SHEBANG_FILE=""
    if ! SCRIPT_RAN_WITH_NEW_SHEBANG_FILE="$(mktemp -p "$__pwd_shebang_script" XXXXXXXX.sync.sh)"; then
        __echo_red_shebang "Cannot create tempt file for new shebang replace"
        return 1
    fi

    __cleanup_shebang_run_tmp_file() {
        __script_file_shebang_rm="${SCRIPT_RAN_WITH_NEW_SHEBANG_FILE:-}"
        
        if [ -z "$__script_file_shebang_rm" ]; then
            return 0
        fi

        if [ ! -f "$__script_file_shebang_rm" ]; then
            return 0
        fi

        if ! rm -f "$__script_file_shebang_rm"; then
            __echo_red_shebang "Cannot remove temp script file '$__script_file_shebang_rm'"
        fi
    }

    trap __cleanup_shebang_run_tmp_file EXIT

    write_shebang_header "$SCRIPT_RAN_WITH_NEW_SHEBANG_FILE"
    if ! cat "$__script_path_shebang" >> "$SCRIPT_RAN_WITH_NEW_SHEBANG_FILE"; then
        __echo_red_shebang "Cannot write script content to '$SCRIPT_RAN_WITH_NEW_SHEBANG_FILE'"
        return 1
    fi

    export SCRIPT_ORIGINAL_PATH="$__script_path_shebang"
    export SCRIPT_RAN_WITH_NEW_SHEBANG="$CONST_SCRIPT_RAN_WITH_NEW_SHEBANG_VAL"
    
    __ret_code="0"
    if bash "$SCRIPT_RAN_WITH_NEW_SHEBANG_FILE" "$@"; then
        true
    else
        __ret_code="$?"
    fi
    
    __cleanup_shebang_run_tmp_file

    exit "$__ret_code"
}

# End vps-init/src/include/02_base_system_01_bash_02_shebang.sh

# Start vps-init/src/include/02_base_system_02_pkg.sh

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

# End vps-init/src/include/02_base_system_02_pkg.sh

# Start vps-init/src/include/02_base_system_04_service.sh

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

# End vps-init/src/include/02_base_system_04_service.sh

# Start vps-init/src/include/02_base_system_05_net.sh

function get_hostname() {
    local hst=""
    if ! hst="$(uname -n)"; then
        hst="host"
    fi

    echo -n "$hst"

    return 0
}

# End vps-init/src/include/02_base_system_05_net.sh

# Start vps-init/src/include/03_base_str_01_generate.sh

# shellcheck disable=SC2329
function rand_str_n() {
    if __rand_str_n "${1-1}"; then
		return 0
	else
		return "$?"
	fi
}

# End vps-init/src/include/03_base_str_01_generate.sh

# Start vps-init/src/include/03_base_str_02_escape.sh

# shellcheck disable=SC2329
function escape_regexp_str() {
	local str="${1:-}"
	if [ -z "$str" ]; then
		echo -n ""
		return 0
	fi; \
	# shellcheck disable=SC2016
	# shellcheck disable=SC2155
	local escaped="$(printf '%s' "$str" | sed 's/[.[\*^$()+?{|]/\\&/g')"
	echo -n "$escaped"
	return 0
}

# shellcheck disable=SC2329
function escape_new_line() {
	__escape_new_line "${1:-}"
	return 0
}

# End vps-init/src/include/03_base_str_02_escape.sh

# Start vps-init/src/include/03_base_str_03_num.sh

# shellcheck disable=SC2329
function num_great_than() {
	if [ "$1" -gt "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_less_than() {
	if [ "$1" -lt "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_great_eq() {
	if [ "$1" -ge "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_less_eq() {
	if [ "$1" -le "$2" ]; then
		return 0
	fi

	return 1
}

# End vps-init/src/include/03_base_str_03_num.sh

# Start vps-init/src/include/03_base_str_04_trim.sh

# shellcheck disable=SC2034
export CONST_STR_TRIM_LEFT="__left__"
# shellcheck disable=SC2034
export CONST_STR_TRIM_RIGHT="__right__"

# shellcheck disable=SC2329
function trim_spaces_left() {
    local trimmed="${1:-}"
    echo -n "${trimmed#"${trimmed%%[![:space:]]*}"}"
	return 0
}

# shellcheck disable=SC2329
function trim_spaces_right() {
    local trimmed="${1:-}"
    echo -n "${trimmed%"${trimmed##*[![:space:]]}"}"
	return 0
}

# shellcheck disable=SC2329
function trim_spaces() {
    local trimmed="${1:-}"
    trimmed="$(trim_spaces_left "$trimmed")"
    trimmed="$(trim_spaces_right "$trimmed")"
    echo -n "$trimmed"
	return 0
}

# shellcheck disable=SC2329
function cut_left_bytes() {
	local str="$1"
	local num="${2}"
	num="$(("$num" + 1))-"
	# shellcheck disable=SC2155
	local res="$(echo -n "$str" | cut -b "$num")"
	echo -n "$res"
	return 0
}

# shellcheck disable=SC2329
function cut_right_bytes() {
	local str="$1"
	local num="${2}"
	# shellcheck disable=SC2155
	local bytes_to_trim="$(echo -n "$str" | wc -c)"
	num="-$(("$bytes_to_trim" - "$num"))"
	# shellcheck disable=SC2155
	local res="$(echo -n "$str" | cut -b "$num")"
	echo -n "$res"
	return 0
}

# shellcheck disable=SC2329
function __trim_by_string_on_side() {
	local symbol="${1:-}"
    local count="${2:-}"
    local side="${3}"
    local str_for_trim="${4:-}"

	if [[ "$symbol" == "" || "$str_for_trim" == "" ]]; then
		echo -n "$str_for_trim"
		return 0
	fi

	# shellcheck disable=SC2034
	# shellcheck disable=SC2155
	local escaped_for_re="$(escape_regexp_str "$symbol")"

	local for_re="$escaped_for_re"
	if [[ "$count" == "" || "$count" == "0" ]]; then
		for_re="(($escaped_for_re)\\2{0,})"
	elif [[ "$count" != "1" ]]; then
		local last=$(("$count" - 1))
		for_re="(($escaped_for_re)\\2{0,$last})"
	fi

	local cut_fun=""

	if [[ "$side" == "$CONST_STR_TRIM_LEFT" ]]; then
		for_re="^${for_re}"
		cut_fun="cut_left_bytes"
	elif [[ "$side" == "$CONST_STR_TRIM_RIGHT" ]]; then
		for_re="${for_re}\$"
		cut_fun="cut_right_bytes"
	fi

	local matched_for_trim=""
	if matched_for_trim="$(echo -n "$str_for_trim" | grep -oP "$for_re")"; then
		# shellcheck disable=SC2155
		local bytes_to_trim="$(echo -n "$matched_for_trim" | wc -c)"
		# shellcheck disable=SC2155
		echo -n "$($cut_fun "$str_for_trim" "$bytes_to_trim")"
		return 0
	fi

	echo -n "$str_for_trim"
	return 0
}

# shellcheck disable=SC2329
function trim_by_string_left() {
    local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	
	__trim_by_string_on_side "$symbol" "$count" "$CONST_STR_TRIM_LEFT" "$str"
	return $?
}

# shellcheck disable=SC2329
function trim_by_string_right() {
    local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	__trim_by_string_on_side "$symbol" "$count" "$CONST_STR_TRIM_RIGHT" "$str"
	return $?
}

# shellcheck disable=SC2329
function trim_by_string() {
	local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	# test cases


	# shellcheck disable=SC2155
	local res="$(trim_by_string_left "$symbol" "$count" "$str")"
	echo -n "$(trim_by_string_right "$symbol" "$count" "$res")"

	return 0
}

# shellcheck disable=SC2329
function trim_string_wrapper() {
    local str="${1:-}"

	local count="1"
	local -a symbols=('"' "'")

	local res="$str"
	for ss in "${symbols[@]}"; do
		res="$(trim_by_string "$ss" "$count" "$str")"
		if [[ "$res" != "$str" ]]; then
			break
		fi
	done

	echo -n "$res"

	return 0
}

# End vps-init/src/include/03_base_str_04_trim.sh

# Start vps-init/src/include/03_base_str_05_split.sh

# shellcheck disable=SC2329
function split_by() {
	local _sep="${1:-}"
	if [ -z "$_sep" ]; then
		echo_error "Separator for split_by not passed as first arg"
		return 1
	fi

	_sep="$(printf '%s\n' "$_sep" | sed 's/[]\/$*.^[]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')"
	
    local _dest="${2:-}"
	
    if [ -z "$_dest" ]; then \
		echo_error "Destination array for split_by not passed as second arg"
		return 1
	fi
	
    local _str="${3:-}"
	
    readarray -t -d '' "$_dest" < <(sed -z "s/$_sep/\x00/g" < <(printf '%s' "$_str"))
	
    local _transform="${4:-}"

	if [ -n "$_transform" ]; then
		local -n target_array="$_dest"
		for _indx in "${!target_array[@]}"; do
    		target_array[_indx]="$("$_transform" "${target_array[_indx]}")"
		done
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_dot() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by '.' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_comma() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by ',' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_space() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by ' ' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_new_line() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by "$CONST_NEW_LINE" "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# End vps-init/src/include/03_base_str_05_split.sh

# Start vps-init/src/include/03_base_str_06_join.sh

# shellcheck disable=SC2329
function append_str_with_separator() {
	local sep="${1:-}"
	local str="${2:-}"
	local app="${3:-}"
	if [ -n "$app" ]; then
		if [ -z "$str" ]; then
			str="$app"
		else
			str="${str}${sep}${app}"
		fi
	fi
	echo -n "$str"
}

# shellcheck disable=SC2329
function append_str_with_new_line() {
	local str="${1:-}"
	local app="${2:-}"
	echo -n "$(append_str_with_separator "$CONST_NEW_LINE" "$str" "$app")"
}


# shellcheck disable=SC2329
function join_args_with_separator() {
	local sep="${1:-}"
	shift

	if [[ "${#@}" == "0" ]]; then
		echo -n ""
		return 0
	fi

	local res=""

	for opt in "$@"; do
		res="$(append_str_with_separator "$sep" "$res" "$opt")"
	done

	echo -n "$res"

	return 0
}

# End vps-init/src/include/03_base_str_06_join.sh

# Start vps-init/src/include/03_base_str_07_diff.sh

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

# End vps-init/src/include/03_base_str_07_diff.sh

# Start vps-init/src/include/04_base_input.sh

# shellcheck disable=SC2034
export CONST_NOT_ASK_VAL="__not_ask__"
# shellcheck disable=SC2034
export CONST_ASK_VAL="__should_ask__"

# shellcheck disable=SC2034
export CONST_READ_ERROR_RET_CODE="254"
# shellcheck disable=SC2034
export CONST_READ_ERROR_WITH_TIMEOUT_RET_CODE="255"

function __prepare_prompt_str() {
    local prompt="${1:-No prompt}"
    local yes_no_out="${2:-}"
    local timeout="${3:-}"

    local yes_no=""
    if [ -n "$yes_no_out" ]; then
        # shellcheck disable=SC2059
        yes_no="$(printf " \e${CONST_COLOR_GREEN}[y/n]\e${CONST_COLOR_NO}")"
    fi

    local timeout_msg=""
    if [ -n "$timeout" ]; then
        timeout_msg="[Read timeout ${timeout}s] "
    fi

    printf "> \e${CONST_COLOR_YELLOW}${timeout_msg}%s\e${CONST_COLOR_NO}${yes_no}: " "$prompt"
}

function __prepare_read_timeout_args() {
    local timeout="${1:-}"

    local timeout_args=""
    local res_timeout=""
    if [ -n "$timeout" ]; then
        if ! res_timeout="$(is_number_positive "$timeout")"; then
            echo_error "Incorrect timeout '$timeout'"
            return 1
        fi

        echo -n "-t $res_timeout"
        return 0
    fi

    echo -n ""
    return 0
}

function __read_error_handle() { 
    local timeout="${1:-}"

    local err_msg="Read error"
    local ret_code="$CONST_READ_ERROR_RET_CODE"
    
    if [ -n "$timeout" ]; then
        ret_code="$CONST_READ_ERROR_WITH_TIMEOUT_RET_CODE"
        err_msg="$err_msg or timeout ${timeout}s is reached"
    fi

    echo_error "${CONST_NEW_LINE}$err_msg"
    return "$ret_code"
}

# shellcheck disable=SC2329
function ask_user() {
    local prompt="${1:-No prompt}"
    local not_ask="${2:-no}"
    local timeout="${3:-}"

    if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
        return 0
    fi

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi

    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "print_yn" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

    if [[ "$answer" == "y" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function ask_user_choice_with_timeout() {
    local prompt="${1:-No prompt}"
    local timeout="${2:-}"
    
    shift
    shift

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi

    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

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
function ask_user_choice() {
    local prompt="${1:-No prompt}"

    shift
    
    local answer=""
    local ret_code=""
    if answer="$(ask_user_choice_with_timeout "$prompt" "" "$@")"; then
        true
    else
        ret_code="$?"
        return "$ret_code"
    fi

    echo -n "$answer"
    return 0
}

# shellcheck disable=SC2329
function ask_user_raw() {
    local prompt="${1-:No prompt}"
    local validator="${2:-${CONST_NO_VALIDATE}}"
    local timeout="${3:-}"

    local timeout_args=""
    if ! timeout_args="$(__prepare_read_timeout_args "$timeout")"; then
        return 1
    fi
    
    local answer=""

    # shellcheck disable=SC2162
    # shellcheck disable=SC2229
    # shellcheck disable=SC2086
    if ! read $timeout_args -p "$(__prepare_prompt_str "$prompt" "" "$timeout")" answer; then
        local ret_code="$CONST_READ_ERROR_RET_CODE"
        if __read_error_handle "$timeout"; then
            true
        else
            ret_code="$?"
        fi
        return "$ret_code"
    fi

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

# End vps-init/src/include/04_base_input.sh

# Start vps-init/src/include/04_base_phases.sh

# shellcheck disable=SC2034
declare -A PHASES_WITH_INDEX=()
# shellcheck disable=SC2034
declare -a COMMANDS_LIST=()

# shellcheck disable=SC2034
export CONST_PHASES_REORDER_FUN_NAME="global_reorder_phase"

# shellcheck disable=SC2329
function phase_get_disable_env() {
    local phase="$1"

    local env_name=""

    local env_fun="phase_${phase}_disable_env"
    if is_function_declared "$env_fun"; then
        env_name="$("$env_fun")"
    fi

    echo -n "$env_name"
}

# shellcheck disable=SC2329
function phase_run_func() {
    local phase="$1"

    local phase_func="phase_${phase}_run"

    if ! is_function_declared "$phase_func"; then
        echo_error "Internal error: '$phase_func' func not declared for phase '$phase'!"
        return 1
    fi

    echo -n "$phase_func"
    return 0
}

# shellcheck disable=SC2329
function phase_change_order() {
    local phase="$1"
    local cur_order="$2"

    local reorder_func="$CONST_PHASES_REORDER_FUN_NAME"

    if ! is_function_declared "$reorder_func" &> /dev/null; then
        echo -n "$cur_order"
        return 0
    fi

    local new_order=""
    if ! new_order="$("$reorder_func" "$phase" "$cur_order")"; then
        echo_error "Cannot call '$reorder_func' to get order for phase '$phase'"
        return 1
    fi

    if [ -z "$new_order" ]; then
        echo_error "'$reorder_func' returned empty order for phase '$phase'"
        return 1
    fi

    echo -n "$new_order"
    return 0
}

# shellcheck disable=SC2329
function phase_print_disable_help() {
    local phase="$1"

    # shellcheck disable=SC2155
    local env_name="$(phase_get_disable_env "$phase")"

    if [ -n "$env_name" ]; then
        echo "Can be disabled with set env ${env_name}=true"
        return 0
    fi

    echo "This phase is required and not be disabled!"
}

# shellcheck disable=SC2329
function phase_is_not_disabled() {
    local phase="$1"

     # shellcheck disable=SC2155
    local env_name="$(phase_get_disable_env "$phase")"

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

# shellcheck disable=SC2329
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
        echo_error "Command '$cmd_name' not found!"
        return 1
    fi

    local run_func="cmd_${cmd_name}_run"

    if ! declare -F "$run_func" > /dev/null; then
        echo_error "Run function $run_func for command $cmd_name not found!"
        return 1
    fi

    shift

    if ! "$run_func" "$@"; then
        echo_error "Command $cmd_name failed" 
        return 1
    fi

    return 0
}

# End vps-init/src/include/04_base_phases.sh

# Start vps-init/src/include/05_base_args.sh

# shellcheck disable=SC2034
export CONST_FLAG_SET="true"
# shellcheck disable=SC2034
export CONST_IS_FLAG="__is_flag__"
# shellcheck disable=SC2034
export CONST_NOT_FLAG="__not_is_flag__"

# shellcheck disable=SC2034
export CONST_NO_VALIDATE="__no_validate"

# shellcheck disable=SC2034
export CONST_ARG_NOT_PASSED="__not_passed_arg__"
# shellcheck disable=SC2034
export CONST_ARG_PASSED="__arg_passed__"

# shellcheck disable=SC2329
function __no_validate() {
    local val="$1"
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
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

function extract_value_argument() { 
    local arg_name="$1"
    local env_name="$2"
    local validator="$3"

    shift
    shift
    shift

    local val=""
    if ! val="$(extract_argument "$arg_name" "$env_name" "$CONST_NOT_FLAG" "$validator" "$@")"; then
        echo -n ""
        return 1
    fi

    echo -n "$val"
    return 0
}

function extract_value_argument_no_validate() { 
    local arg_name="$1"
    local env_name="$2"

    shift
    shift

    local val=""
    if ! val="$(extract_argument "$arg_name" "$env_name" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo -n ""
        return 1
    fi

    echo -n "$val"
    return 0
}

function arg_flag_is_set() {
    local arg_name="$1"
    local env_name="${2}"

    shift
    shift

    # shellcheck disable=SC2155
    local res="$(extract_argument "$arg_name" "$env_name" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"
    if [[ "$res" == "$CONST_FLAG_SET" ]]; then
        return 0
    fi

    return 1
}

# End vps-init/src/include/05_base_args.sh

# Start vps-init/src/include/06_base_validate_01_base.sh

export CONST_VALIDATE_SHOULD_OPTIONAL="optional"
export CONST_VALIDATE_SHOULD_PASSED="passed"

# shellcheck disable=SC2329
function call_validate_fun() {
    local is_optional="$1"
    local validate_fun="$2"
    local val="$3"
    local passed="$4"

    if ! is_function_declared "$validate_fun"; then
        echo_error "Validation function '$validate_fun' is not declared"
        return 1
    fi

    if [[ "$is_optional" == "$CONST_VALIDATE_SHOULD_OPTIONAL" ]]; then
        if [[ "$passed" == "$CONST_ARG_NOT_PASSED" || "$val" == "" ]]; then
            echo -n ""
            return 0
        fi
    fi

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo_error "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo_error "Empty arg val"
        return 1 
    fi

    if ! val="$("$validate_fun" "$val")"; then
        return 1
    fi

    echo -n "$val"
    return 0
}

# End vps-init/src/include/06_base_validate_01_base.sh

# Start vps-init/src/include/06_base_validate_02_str.sh

# shellcheck disable=SC2329
function validate_arg_not_empty() {
    local val="$1"
    local passed="$2"

    function __dummy_validate() {
        echo -n "$1"
    }

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "__dummy_validate" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function check_is_number() {
    local val="$1"

    if ! [[ $val =~ ^-?[0-9]+$ ]]; then
        echo_error "'$val' is not number!"
        return 1
    fi

    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_number() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_number" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_number" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function is_number_positive() {
    local val="$1"
    local have_zero="${2:-}"

    if ! val="$(check_is_number "$val")"; then
        return 1
    fi

    local err_num="1"

    if [ -n "$have_zero" ]; then
        err_num="0"
        if [ "$val" -ge "0" ]; then
            echo -n "$val"
            return 0
        fi
    else 
        err_num="1"
        if [ "$val" -gt "0" ]; then
            echo -n "$val"
            return 0
        fi
    fi

    echo_error "Number '$val' < $err_num"
    return 0
}

# shellcheck disable=SC2329
function is_number_positive_or_zero() {
    is_number_positive "$1" "true"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_positive() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_number_positive" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_number_positive_or_zero() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_number_positive_or_zero" "$val" "$passed"
    return $?
}

# End vps-init/src/include/06_base_validate_02_str.sh

# Start vps-init/src/include/06_base_validate_03_bash.sh

# shellcheck disable=SC2329
function validate_arg_func_declared() {
    local val="$1"
    local passed="$2"

    if ! call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "is_function_declared" "$val" "$passed"; then
        return 1
    fi
    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_func_declared_optional() {
    local val="$1"
    local passed="$2"

    if ! call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "is_function_declared" "$val" "$passed"; then
        return 1
    fi
    
    echo -n "$val"
    return 0
}

# End vps-init/src/include/06_base_validate_03_bash.sh

# Start vps-init/src/include/06_base_validate_04_fs.sh

# shellcheck disable=SC2329
function check_file_is_not_empty() {
    local val="$1"

    local real=""

    if ! real="$(realpath "$val")"; then
        echo_error "Cannot extract real path for '$val'"
        return 1
    fi

    if [ ! -f "$real" ]; then
        echo_error "'$val' is not file!"
        return 1
    fi

    if [ ! -s "$real" ]; then
        echo_error "'$val' is empty file!"
        return 1
    fi

    echo -n "$real"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_not_empty_file() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_file_is_not_empty" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_not_empty_file_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_file_is_not_empty" "$val" "$passed"
    return $?
}

# End vps-init/src/include/06_base_validate_04_fs.sh

# Start vps-init/src/include/06_base_validate_05_net.sh

# shellcheck disable=SC2329
function check_is_number_port() {
    local port="$1"

    if ! port="$(check_is_number "$port" "$CONST_ARG_PASSED")"; then
        echo_error "Port is not number"
        return 1
    fi

    if [ "$port" -gt "0" ] && [ "$port" -le "65535" ]; then
        echo -n "$port"
        return 0
    fi

    echo_error "Port '$port' should be >= 1 and <=  65535"
    return 1
}

# shellcheck disable=SC2329
function validate_arg_port() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_number_port" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_port_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_number_port" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function check_is_ipv4() {
    local val="$1"
    local regexp='^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if [[ "$val" =~ $regexp ]]; then
        echo -n "$val"
        return 0
    fi 

    echo_error "Incorrect IPv4 '$val'"
    return 1
}

# shellcheck disable=SC2329
function validate_arg_ipv4() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_PASSED" "check_is_ipv4" "$val" "$passed"
    return $?
}

# shellcheck disable=SC2329
function validate_arg_ipv4_optional() {
    local val="$1"
    local passed="$2"

    call_validate_fun "$CONST_VALIDATE_SHOULD_OPTIONAL" "check_is_ipv4" "$val" "$passed"
    return $?
}

# End vps-init/src/include/06_base_validate_05_net.sh

# Start vps-init/src/include/07_base_global_args_01_help.sh

declare -a CONST_HELP_AGS=("-h" "--help")

# shellcheck disable=SC2329
function is_help_flag_set() {
    for ha in "${CONST_HELP_AGS[@]}"; do 
        if arg_flag_is_set "$ha" "" "$@"; then
            return 0
        fi
    done

    return 1
}

# shellcheck disable=SC2329
function echo_help_args_help() {
    local args_list=""

    for hah in "${CONST_HELP_AGS[@]}"; do
        if [ -z "$args_list" ]; then
            args_list="$hah"
            continue
        fi

        args_list="${args_list}|${hah}"
    done 

    echo -n "
    ${args_list}
      Show this help message."
}

# End vps-init/src/include/07_base_global_args_01_help.sh

# Start vps-init/src/include/07_base_global_args_02_config.sh

# shellcheck disable=SC2034
export CONST_CONFIG_FILE_ARG="--config"
# shellcheck disable=SC2034
export CONST_CONFIG_FILE_ENV="CONFIG_PATH"

# shellcheck disable=SC2034
export PROTECTED_PASSED_CONFIG_FILE=""

# shellcheck disable=SC2329
function parse_and_apply_config_file() {
    if is_help_flag_set "$@"; then
        return 0
    fi

    local config=""

    if ! config="$(extract_value_argument "$CONST_CONFIG_FILE_ARG" "$CONST_CONFIG_FILE_ENV" "validate_arg_not_empty_file_optional" "$@")"; then
        echo_error "Passed config is incorrect: $config"
        return 1
    fi

    if [ -n "$config" ]; then
        echo_info "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a

        PROTECTED_PASSED_CONFIG_FILE="$config"
    fi
}

# shellcheck disable=SC2329
function check_config_file_set_and_get() {
    if [ -z "${PROTECTED_PASSED_CONFIG_FILE:-}" ]; then
        return 1
    fi

    echo -n "$PROTECTED_PASSED_CONFIG_FILE"
    return 0
}

# shellcheck disable=SC2329
function config_file_help() {
    echo -n "
    ${CONST_CONFIG_FILE_ARG}
      Path to config with envs to settings.
      Should be .env format
      Env $CONST_CONFIG_FILE_ENV" sor set.
}

# End vps-init/src/include/07_base_global_args_02_config.sh

# Start vps-init/src/include/07_base_global_args_04_not_ask.sh

# shellcheck disable=SC2034
export CONST_NOT_ASK_ARG="--not-ask"
# shellcheck disable=SC2034
export CONST_NOT_ASK_ENV="NOT_ASK"

# shellcheck disable=SC2329
function parse_not_ask() {
    if arg_flag_is_set "$CONST_NOT_ASK_ARG" "$CONST_NOT_ASK_ENV" "$@"; then
        echo -n "$CONST_NOT_ASK_VAL"
        return 0
    fi

    echo "$CONST_ASK_VAL"
    return 0
}

# shellcheck disable=SC2329
function not_ask_help() {
    echo -n "
    ${CONST_NOT_ASK_ARG}
      If passed will not ask user about actions.
      Env ${CONST_NOT_ASK_ENV}=true for set."
}

# End vps-init/src/include/07_base_global_args_04_not_ask.sh

# Start vps-init/src/include/07_base_global_args_05_log.sh

# shellcheck disable=SC2034
export CONST_LOG_ARG_ENABLE_DEBUG="--log-enable-debug"
# shellcheck disable=SC2034
export CONST_LOG_ENV_ENABLE_DEBUG="LOG_ENABLE_DEBUG"
# shellcheck disable=SC2034
export CONST_LOG_ARG_FILE="--log-file"
# shellcheck disable=SC2034
export CONST_LOG_ENV_FILE="LOG_SCRIPT_FILE"
# shellcheck disable=SC2034
export CONST_LOG_ARG_UNIX_SECONDS="--log-add-unix-seconds-to-file-path"
# shellcheck disable=SC2034
export CONST_LOG_ENV_UNIX_SECONDS="LOG_UNIX_SECONDS_TO_PATH"

# shellcheck disable=SC2329
function parse_and_apply_log_settings() {
    if arg_flag_is_set "$CONST_LOG_ARG_ENABLE_DEBUG" "$CONST_LOG_ENV_ENABLE_DEBUG" "$@"; then
        __enable_debug_log "true"
    fi

    local log_file=""
    if ! log_file="$(extract_value_argument_no_validate "$CONST_LOG_ARG_FILE" "$CONST_LOG_ENV_FILE" "$@")"; then
        echo_error "Cannot extract log file argument"
        return 1
    fi

    if [ -n "$log_file" ]; then
        if arg_flag_is_set "$CONST_LOG_ARG_UNIX_SECONDS" "$CONST_LOG_ENV_UNIX_SECONDS" "$@"; then
            local log_file_suf=""
            if ! log_file_suf="$(date +%s)"; then
                echo_error "Cannot get suffix for log file"
                return 1
            fi
            log_file="${log_file}.${log_file_suf}"
        fi

        if ! __set_log_file "$log_file"; then
            echo_error "Cannot set log file '$log_file'"
            return 1
        fi
    fi

    return 0
}

# shellcheck disable=SC2329
function log_settings_help() {
    echo -e "
    ${CONST_COLOR_GREEN}Log settings:${CONST_COLOR_NO}
    $CONST_LOG_ARG_ENABLE_DEBUG
      If passed will output debug log information to terminal.
      Env ${CONST_LOG_ENV_ENABLE_DEBUG}=true for set.

    $CONST_LOG_ARG_FILE 'PATH'
      If set, all log include debug will write to file in format:
      [\$date] || [\$level]: \$msg
      Env $CONST_LOG_ENV_FILE

    $CONST_LOG_ARG_UNIX_SECONDS
      If set and pass log file path, will add unix time seconds
      as suffix of file path like (log file is /tmp/init-log.log):
        /tmp/init-log.log.1790520136
      Env ${CONST_LOG_ENV_UNIX_SECONDS}=true for set."
 }

# End vps-init/src/include/07_base_global_args_05_log.sh

# Start vps-init/src/include/07_base_global_args_06_screen.sh

export CONST_SCREEN_ARG_ENABLE="--screen-enable-run-via-screen"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_ENABLE="SCREEN_ENABLE_RUN_VIA_SCREEN"

# shellcheck disable=SC2034
export CONST_SCREEN_ARG_RECORD_DIR="--screen-records-dir"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_RECORD_DIR="SCREEN_RECORDS_DIR"

# shellcheck disable=SC2034
export CONST_SCREEN_ARG_SESS_NAME="--screen-session-name-prefix"
# shellcheck disable=SC2034
export CONST_SCREEN_ENV_SESS_NAME="SCREEN_SESSION_NAME_PREFIX"

# shellcheck disable=SC2329
function __screen_sess_prefix_default() {
    local screen_sess_name="$1"
    local passed="${2:-}"

    if [[ "$screen_sess_name" == "" || "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        screen_sess_name="$CONST_SCREEN_DEFAULT_SESS_NAME"
    fi

    echo -n "$screen_sess_name"
    return 0
}

# shellcheck disable=SC2329
function __screen_root_dir_default() {
    local screen_records_dir="$1"
    local sess_name="${2}"

    if [ -z "$screen_records_dir" ]; then
        if [ -n "${HOME:-}" ]; then
            screen_records_dir="${HOME}/${sess_name}"
        else
            screen_records_dir="/root"
        fi
    fi

    echo -n "$screen_records_dir"
    return 0
}

# shellcheck disable=SC2329
function parse_screen_args() {
    local enable_screen_dest_name="$1"
    local screen_records_dir_dest_name="$2"
    local screen_sess_name_dest_name="$3"

    if [ -z "$enable_screen_dest_name" ]; then
        echo_error "enable screen dest name variable is empty"
        return 1
    fi

    if [ -z "$screen_records_dir_dest_name" ]; then
        echo_error "screen records dest name variable is empty"
        return 1
    fi

    if [ -z "$screen_sess_name_dest_name" ]; then
        echo_error "screen session name variable name is empty"
        return 1
    fi

    local -n enable_screen_ref="$enable_screen_dest_name"
    local -n screen_records_dir_ref="$screen_records_dir_dest_name"
    local -n screen_sess_name_ref="$screen_sess_name_dest_name"

    enable_screen_ref="$CONST_SCREEN_NOT_RUN_IN_SCREEN"
    screen_records_dir_ref=""
    screen_sess_name_ref=""

    shift
    shift
    shift

    if arg_flag_is_set "$CONST_SCREEN_ARG_ENABLE" "$CONST_SCREEN_ENV_ENABLE" "$@"; then
        # shellcheck disable=SC2034
        if ! screen_sess_name_ref="$(extract_value_argument "$CONST_SCREEN_ARG_SESS_NAME" "$CONST_SCREEN_ENV_SESS_NAME" "__screen_sess_prefix_default" "$@")"; then
            echo_error "Cannot extract screen session name  argument"
            return 1
        fi

        if ! screen_records_dir_ref="$(extract_value_argument_no_validate "$CONST_SCREEN_ARG_RECORD_DIR" "$CONST_SCREEN_ENV_RECORD_DIR" "$@")"; then
            echo_error "Cannot extract screen records log dir argument"
            return 1
        fi

        # shellcheck disable=SC2034
        if ! screen_records_dir_ref="$(__screen_root_dir_default "$screen_records_dir_ref" "$screen_sess_name_ref")"; then
            echo_error "Cannot apply screen records log dir argument"
            return 1
        fi
        # shellcheck disable=SC2034
        enable_screen_ref="$CONST_SCREEN_SHOULD_REPLACED"
    fi
    
    return 0
}

# shellcheck disable=SC2329
function screen_args_help() {
    echo -e "
    ${CONST_COLOR_GREEN}Run via GNU screen options:${CONST_COLOR_NO}
    $CONST_SCREEN_ARG_ENABLE
      By default, script run without GNU screen.
      If passed, enable run via screen.
      Env ${CONST_SCREEN_ENV_ENABLE}=true for set.
    $CONST_SCREEN_ARG_RECORD_DIR 'DIR_PATH'
      Dir for save output screen.
      If dir not exists, it will create.
      By default, \${HOME} is set, will be \${HOME}/\${session_name_prefix}, else /root
      Env $CONST_SCREEN_ENV_RECORD_DIR for set.
    $CONST_SCREEN_ARG_SESS_NAME 'NAME'
      Screen session name prefix.
      By default, $CONST_SCREEN_DEFAULT_SESS_NAME
      Env $CONST_SCREEN_ENV_SESS_NAME for set."
}

# End vps-init/src/include/07_base_global_args_06_screen.sh

# Start vps-init/src/include/08_base_screen.sh

# shellcheck disable=SC2034
declare -A CONST_PRIVATE_SCREEN_PACKAGES=()

CONST_PRIVATE_SCREEN_PACKAGES["$SYS_PACKAGES_ENGINE_APT"]="screen"
CONST_PRIVATE_SCREEN_PACKAGES["$SYS_PACKAGES_ENGINE_APK"]="screen"

# shellcheck disable=SC2034
export CONST_SCREEN_REPLACED_VAL="__in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_SHOULD_REPLACED="__should_run_in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_NOT_RUN_IN_SCREEN="__not_run_in_screen__"
# shellcheck disable=SC2034
export CONST_SCREEN_DEFAULT_SESS_NAME="server-init"

# shellcheck disable=SC2329
function screen_install() {
    # shellcheck disable=SC2155
    local pkg_manager="$(get_package_manager)"
    local screen_pkg=""
    if [[ -v CONST_PRIVATE_SCREEN_PACKAGES["$pkg_manager"] ]]; then
        screen_pkg="${CONST_PRIVATE_SCREEN_PACKAGES["$pkg_manager"]}"
    else
        echo_error "Cannot find screen package for package manager '$pkg_manager'"
        return 1
    fi

    if check_packages_installed "$screen_pkg"; then
        echo_debug "screen package '$screen_pkg' already installed"
        return 0
    fi

    if ! install_packages "$screen_pkg"; then
        echo_error "Cannot install screen package '$screen_pkg'"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function screen_replace_run_with_screen() {
    local need_screen_run="${1}"
    local screen_sess_name="${2:-}"
    local screen_records_dir="${3:-}"
    local script_file="${4:-}"

    shift
    shift
    shift
    shift

    local envs_set_str=""
    if envs_set_str="$(env)"; then
        local -a screen_envs_list=()
        if split_by_new_line "screen_envs_list" "$envs_set_str"; then
            for se_e in "${screen_envs_list[@]}"; do
                local screen_env=""
                if screen_env="$(echo "$se_e" | grep -i "_screen")"; then
                    true
                elif screen_env="$(echo "$se_e" | grep -iP "^term=")"; then
                    true
                else
                    continue
                fi
                echo_debug "Found screen env: '$screen_env'"
            done
        else
            echo_debug "Error split envs for out screen envs"
        fi
    else
        echo_debug "Error 'env' run for out screen envs"
    fi


    if [[ "$need_screen_run" == "$CONST_SCREEN_NOT_RUN_IN_SCREEN"  ]]; then
        echo_debug "Disable run in screen. Skip replace"
        return 0
    fi

    if [[ "${SYNC_SCREEN_REPLACED:-}" == "$CONST_SCREEN_REPLACED_VAL" || "${TERM:-}" == screen* ]]; then
        echo_debug "Already run with screen. Skip replace"
        return 0
    fi

    if ! screen_install; then
        echo_error "Cannot install screen"
        return 1
    fi

    if ! screen_sess_name="$(__screen_sess_prefix_default "$screen_sess_name" "$CONST_ARG_PASSED")"; then
        echo_error "Cannot apply screen session name"
        return 1
    fi


    if ! screen_records_dir="$(__screen_root_dir_default "$screen_records_dir" "$screen_sess_name")"; then
        echo_error "Cannot apply screen records log dir argument"
        return 1
    fi

    if [ ! -d "$screen_records_dir" ]; then
        if ! mkdir -p "$screen_records_dir"; then
            echo_error "Cannot create screen records log '$screen_records_dir'"
            return 1
        fi
    fi

    local dt=""
    if dt="$(date +'%Y-%m-%d_%H-%M-%S')"; then
        dt="${dt}-"
    else
        dt=""
    fi

    # shellcheck disable=SC2155
    export SYNC_ID="${screen_sess_name}-$(__rand_str_n "6")"

    export SYNC_SCREEN_SESS_NAME="$SYNC_ID"

    export SYNC_SCREEN_SESS_LOG_FILE="${screen_records_dir}/${dt}record-${SYNC_SCREEN_SESS_NAME}.log"

    if [ -z "$script_file" ]; then
        script_file="$CONST_SCRIPT_NAME"
    fi

    echo_debug "Star replace to screen"
    export SYNC_SCREEN_REPLACED="$CONST_SCREEN_REPLACED_VAL"

    local ret_code_screen="0"
    # shellcheck disable=SC2091
    # shellcheck disable=SC2154
    if $(exec screen -S "$SYNC_SCREEN_SESS_NAME" -L -Logfile "$SYNC_SCREEN_SESS_LOG_FILE" "$script_file" "$@"); then
        true
    else
        ret_code_screen="$?"
        echo_warn "screen returns error code $ret_code_screen"
    fi

    local exit_code="255"

    if [ -f "$SYNC_SCREEN_SESS_LOG_FILE" ]; then
        cat "$SYNC_SCREEN_SESS_LOG_FILE" || true
        echo_warn "Screen log: '$SYNC_SCREEN_SESS_LOG_FILE'. If need, remove with command"
        echo_warn "  rm -fv '$SYNC_SCREEN_SESS_LOG_FILE'"
        local exit_code_msg=""
        if exit_code_msg="$(grep -Po "${CONST_FAIL_MAIN_EXIT_CODE_PREFIX}\\d+" "$SYNC_SCREEN_SESS_LOG_FILE")"; then
            local exit_code_num=""
            if exit_code_num="$(echo "$exit_code_msg" | grep -Po "\\d+")"; then
                exit_code="$(trim_spaces "$exit_code_num")"
                echo_debug "Extracted exit code from screen log: '$exit_code'"
            fi
        else
            exit_code="0"
        fi
    fi

    exit "$exit_code"
}

# End vps-init/src/include/08_base_screen.sh

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

# Start vps-init/src/include/11_base_jq.sh

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

# End vps-init/src/include/11_base_jq.sh

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

        if grep -q "$ssh_key" "$auth_keys_file"; then
            delete_file "$tmp_file" || true
            echo_green "SSH key '$ssh_key' already present in '$auth_keys_file'. Content:"
            tee_log_command_out_force cat "$auth_keys_file" || true
            return 0
        fi

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

