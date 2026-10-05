#!/usr/bin/env bash

set -Eeuo pipefail

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
	return 0
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