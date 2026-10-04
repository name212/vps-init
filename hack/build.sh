#!/usr/bin/env bash

set -Eeuo pipefail

# Args passwd va envs:
#   PARENT_BUILD_ROOT_DIR - pass this module dir if use as submodule
#   DEST_FILE - pass if need rewrite destination of sync script
#   SKIP_FILES - comma separated files names in libs to skip
#   BUILD_AS_LIB - if passed build libraries file only
#   WRITE_SHEBANG_LIB_BEFORE_MAIN - pass non empty if need write shebang lib before main header

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

function get_parent_dir() {
    local parent_dir="${PARENT_BUILD_ROOT_DIR:-}"

    if [ -n "$parent_dir" ]; then
        echo -n "$parent_dir"
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function get_path_for_file() {
    local path="$1"

    if [ -f "$path" ]; then
        echo -n "$path"
        return 0
    fi

    local full_path=""

    local parent_dir=""
    if parent_dir="$(get_parent_dir)"; then
        full_path="${parent_dir}/$path"
        if [ -f "$full_path" ]; then
            echo -n "$full_path"
            return 0
        fi
    fi
    
    echo_red "Cannot found '$path' when build"
    echo_red "If you use this as submodule, please pass PARENT_BUILD_ROOT_DIR env"
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

function get_shebang_lib_path() {
    local shebang_lib_source="src/include/02_base_system_01_bash_02_shebang.sh"
    if ! shebang_lib_source="$(get_path_for_file "$shebang_lib_source")"; then
        return 1
    fi

    echo -n "$shebang_lib_source"
    return 0
}

function write_main_header() {
    local should_append=""

    if [ -n "${WRITE_SHEBANG_LIB_BEFORE_MAIN:-}" ]; then
        local shebang_lib_source=""
        if ! shebang_lib_source="$(get_shebang_lib_path)"; then
            echo_red "Cannot found shebang source"
            return 1
        fi

        echo_green "Write shebang lib $shebang_lib_source to $destination"
        cat "$shebang_lib_source" > "$destination"
        should_append="true"
    fi

    local header="src/main_header.sh"

    if [ -s "$header" ]; then
        echo_green "Write main header $header to $destination"
        if [ -z "$should_append" ]; then
            cat "$header" > "$destination"
        else
            echo "" >> "$destination"
            cat "$header" >> "$destination"
        fi
    fi

    return 0
}

function write_main_footer() {
    local footer_file="src/main_footer.sh"

    if [ -s "$footer_file" ]; then
        echo_green "Write main footer $footer_file to $destination"
        write_file "$footer_file" "$destination"
    fi
}

function write_lib_files() {
    local parent_dir="${1:-}"
    if [ -n "$parent_dir" ]; then
        echo_green "Passes non empty parent dir '$parent_dir'. Cd to it"
        if ! pushd . > /dev/null; then
            echo_red "Cannot pushd ."
            return 1
        fi

        if ! cd "$parent_dir"; then
            popd || true
            echo_red "cd $parent_dir"
            return 1
        fi
    fi
     
    for fl in $(find "src/include" -name "*.sh" -type f | sort -n); do
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

    if [ -n "$parent_dir" ]; then
        if ! popd > /dev/null; then
            echo_red "cannot popd"
            return 1
        fi
    fi

    return 0
}

function write_main() {
    if is_lib_build; then
        return 0
    fi

    local main_path="src/main.sh"
    if ! main_path="$(get_path_for_file "$main_path")"; then
        return 1
    fi

    write_file "$main_path" "$destination"
}

function create_shebang_lib_if_need() {
    if ! is_lib_build; then
        return 0
    fi

    echo_green "Create shebang lib file"

    local shebang_lib_dest="${destination%.sh}"
    shebang_lib_dest="${shebang_lib_dest}-shebang.sh"
    
    echo_green "Remove previous shebang lib '$shebang_lib_dest'"
    if ! rm -f "$shebang_lib_dest"; then
        echo_red "Cannot remove '$shebang_lib_dest'"
        return 1
    fi

    local shebang_lib_source=""
    if ! shebang_lib_source="$(get_shebang_lib_path)"; then
        echo_red "Cannot found shebang source"
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

    local -a libs_dirs=("")

    local parent_dir=""
    if parent_dir="$(get_parent_dir)"; then
        libs_dirs=("$parent_dir" "")
    fi

    for lib_dir in "${libs_dirs[@]}"; do
        echo_green "Write libs from '$lib_dir'"
        if ! write_lib_files "$lib_dir"; then
            fail_build "write lib files from '$lib_dir'"
        fi
    done

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
