#!/usr/bin/env bash

destination="init.sh"

if [ -n "$DEST_FILE" ]; then
    destination="$DEST_FILE"
fi

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
        echo "$fl not found"
        exit 1
    fi

    echo "Write $fl to $dest"
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

echo "Write $header to $destination"
cat "$header" > "$destination"

for fl in $(find src/include -name "*.sh" -type f | sort); do
    bs="$(basename "$fl")"
    if [[ -v skip_build["$bs"] ]]; then
        echo "!!!! Skip add $fl to $destination because it in skip !!!"
        continue
    fi
    write_file "$fl" "$destination"
done

if [ -z "$BUILD_AS_LIB" ]; then
    write_file "src/main.sh" "$destination"
fi

chmod 755 "$destination"