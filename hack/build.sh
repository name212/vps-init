#!/usr/bin/env bash

WORKING_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function echo_red(){
    echo -e "\033[1;31m$1\033[0m" >&2
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m" >&2
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m" >&2
}

destination="init.sh"

if [ -n "$DEST_FILE" ]; then
    destination="$DEST_FILE"
fi

echo_green "Working in '$$WORKING_DIR'; Destination - '$destination' "

declare -A skip_build=()

if [ -n "$SKIP_FILES" ]; then
    declare -a list_skip_build=()
    IFS=',' read -r -a list_skip_build <<< "$SKIP_FILES"
    for sk in "${list_skip_build[@]}"; do
        skip_build["$sk"]="true"
    done
fi

function remove_begin_spaces() {
    local content="$1"
    while [[ "$content" == [[:space:]]* ]]; do
        content="${content#[[:space:]]}"
    done
    echo "$content"
}

function write_file() {
    local fl="$1"
    local dest="$2"

    if [ ! -f "$fl" ]; then
        echo_red "$fl not found"
        exit 1
    fi

    echo_green "Write $fl to $dest"
    content="$(sed 's/#!\/usr\/bin\/env bash//g' "$fl" | sed 's/set -Eeuo pipefail//g')"
    content="$(remove_begin_spaces "$content")"
    {
        echo "# Start $fl"
        echo ""
        echo "$content"
        echo ""
        echo "# End $fl"
        echo ""
    } >> "$dest"
}

header="src/main_header.sh"

echo_green "Write $header to $destination"
cat "$header" > "$destination"

for fl in $(find src/include -name "*.sh" -type f | sort); do
    bs="$(basename "$fl")"
    if [[ -v skip_build["$bs"] ]]; then
        echo_yellow "!!!! Skip add $fl to $destination because it in skip !!!"
        continue
    fi
    write_file "$fl" "$destination"
done

if [ -z "$BUILD_AS_LIB" ]; then
    write_file "src/main.sh" "$destination"
fi

chmod 755 "$destination"