#!/usr/bin/env bash

set -Eeuo pipefail

WORKING_DIR="$(pwd)"
WORKING_DIR="$(realpath "$WORKING_DIR")"

base_working="$(basename "$WORKING_DIR")"

destination="sync.sh"

if [ -n "${DEST_FILE:-}" ]; then
    destination="$DEST_FILE"
fi

declare -a for_chmod=("$destination")

declare -A skip_build=()

function echo_red(){
    echo -e "\033[1;31m$1\033[0m" >&2
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m" >&2
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m" >&2
}

function is_lib_build() {
    if [ -n "${BUILD_AS_LIB:-}" ]; then
        return 0
    fi

    return 1
}

function calc_skipped_files() {
    if [ -z "${SKIP_FILES:-}" ]; then
        return 0
    fi

    echo_yellow "Skip files passed. Calculate"
    declare -a list_skip_build=()
    IFS=',' read -r -a list_skip_build <<< "$SKIP_FILES"
    for sk in "${list_skip_build[@]}"; do
        skip_build["$sk"]="true"
    done

    return 0
}

function remove_begin_spaces() {
    local content="$1"
    while [[ "$content" == [[:space:]]* ]]; do
        content="${content#[[:space:]]}"
    done
    echo "$content"
    return 0
}

function write_file() {
    local fl="$1"
    local dest="$2"

    if [ ! -f "$fl" ]; then
        echo_red "$fl not found"
        return 1
    fi

    echo_green "Write $fl to $dest"
    content="$(sed -r 's/#!\/usr\/bin\/env (ba)?sh//g' "$fl" | sed 's/set -Eeuo pipefail//g')"
    content="$(remove_begin_spaces "$content")"
    {
        echo "# Start ${base_working}/${fl}"
        echo ""
        echo "$content"
        echo ""
        echo "# End ${base_working}/${fl}"
        echo ""
    } >> "$dest"

    return 0
}

function write_main_header() {
    local header="src/main_header.sh"

    if [ -s "$header" ]; then
        echo_green "Write main header $header to $destination"
        cat "$header" > "$destination"
    fi
}

function write_main_footer() {
    local footer_file="src/main_footer.sh"

    if [ -s "$footer_file" ]; then
        echo_green "Write main footer $footer_file to $destination"
        write_file "$footer_file" "$destination"
    fi
}

function write_lib_files() { 
    for fl in $(find src/include -name "*.sh" -type f | sort -n); do
        bs="$(basename "$fl")"
        if [[ "$bs" == *.test.sh ]]; then
            echo_yellow "Found test file '$fl' Skip"
            continue
        fi

        if [[ -v skip_build["$bs"] ]]; then
            echo_yellow "Skip add $fl to $destination because it in skip"
            continue
        fi

        write_file "$fl" "$destination"
    done
}

function write_main() {
    if ! is_lib_build; then
        write_file "src/main.sh" "$destination"
    fi
}

function create_shebang_lib_if_need() {
    if ! is_lib_build; then
        return 0
    fi

    echo_green "Create shebang lib file"

    local shebang_lib_dest="${destination%.sh}"
    shebang_lib_dest="${shebang_lib_dest}-shebang.sh"
    
    echo_green "Remove previous shebang lib '$$shebang_lib_dest'"
    if ! rm -f "$shebang_lib_dest"; then
        echo_red "Cannot remove '$shebang_lib_dest'"
        return 1
    fi
    
    local shebang_lib_source="src/include/02_base_system_01_bash_02_shebang.sh"
    
    if [ ! -s "$shebang_lib_source" ]; then
        echo_red "Shebang source '$shebang_lib_source' not found"
        return 1
    fi

    echo_green "Copy shebang lib from '$shebang_lib_source' to '$shebang_lib_dest'"

    if ! cp "$shebang_lib_source" "$shebang_lib_dest"; then
        echo_red "Cannot copy '$shebang_lib_source' to '$shebang_lib_dest'"
        return 1
    fi

    for_chmod+=("$shebang_lib_dest")
}

function make_files_executable() {
    local failed=""

    for fl_cm in "$@"; do
        if ! chmod 755 "$fl_cm"; then
            echo_yellow "Cannot chmod 755 '$fl_cm'"
            failed="true"
        fi
    done

    if [ -n "$failed" ]; then
        return 1
    fi

    return 0
}

function fail_build() {
    local fail_on=${1:-unknown}
    echo_red "Build failed on ${fail_on}!"
    exit 1
}

function build_type_str() {
    local type_str="Sync"
    if is_lib_build; then
        type_str="Library"
    fi

    echo -n "$type_str"

    return 0
}

function main() {
    echo_green "$(build_type_str) build started!"
    echo_green "Working in '$WORKING_DIR'; Destination - '$destination'"
    echo ""

    echo_green "Remove previous '$destination'"
    if ! rm -f "$destination"; then
        fail_build "remove previous '$destination'"
    fi

    if ! calc_skipped_files; then
        fail_build "calculate skipped files"
    fi

    if ! write_main_header; then
        fail_build "write main header"
    fi

    if ! write_lib_files; then
        fail_build "write lib files"
    fi

    if ! write_main; then
        fail_build "write main body"
    fi

    if ! write_main_footer; then
        fail_build "write main footer"
    fi

    if ! create_shebang_lib_if_need; then
        fail_build "create shebang lib"
    fi

    if ! make_files_executable "${for_chmod[@]}"; then
        fail_build "make files executable"
    fi

    echo ""
    echo_green "$(build_type_str) build done! Next executable files were created:"
    for d_fl in "${for_chmod[@]}"; do
        echo_green "  $d_fl"
    done

    exit 0
}

main "$@"
