#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function escape_regexp_str() {
	local str="${1:-}"
	if [ -z "$str" ]; then
		echo -n ""
		return 0
	fi
	# shellcheck disable=SC2016
	# shellcheck disable=SC2155
	local escaped="$(printf '%s' "$str" | sed 's/[].[\*^$()+?{|]/\\&/g')"
	echo -n "$escaped"
	return 0
}

# shellcheck disable=SC2329
function escape_new_line() {
	__escape_new_line "${1:-}"
	return 0
}

# shellcheck disable=SC2329
function remove_color_commands_from_string() {
	local str="${1:-}"
	# shellcheck disable=SC2155
	local res="$(echo -n "$str" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")"
	echo -n "$res"
	return 0
}
