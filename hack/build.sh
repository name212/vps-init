#!/usr/bin/env bash

destination="init.sh"

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
    write_file "$fl" "$destination"
done

write_file "src/main.sh" "$destination"

chmod 755 "$destination"