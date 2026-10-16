#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function rand_str_n() {
    if __rand_str_n "${1-1}"; then
		return 0
	else
		return "$?"
	fi
}

# shellcheck disable=SC2329
function str_eq() {
	if [[ "$1" == "$2" ]]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function str_empty() {
	if [ -z "$1" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function str_upper() {
	local str="${1:-}"

	echo -n "${str^^}"

	return 0
}
# shellcheck disable=SC2329
function str_lower() {
	local str="${1:-}"
	
	echo -n "${str,,}"

	return 0
}