#!/usr/bin/env bash

set -Eeuo pipefail

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