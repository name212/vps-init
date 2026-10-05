#!/usr/bin/env sh

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
    if ! SCRIPT_RAN_WITH_NEW_SHEBANG_FILE="$(mktemp -p "$__pwd_shebang_script" "tmp-sync.sh.XXXXXX")"; then
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
