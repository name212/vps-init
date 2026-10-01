#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function split_by() {
	local _sep="${1:-}"
	if [ -z "$_sep" ]; then
		echo_error "Separator for split_by not passed as first arg"
		return 1
	fi

	_sep="$(printf '%s\n' "$_sep" | sed 's/[]\/$*.^[]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')"
	
    local _dest="${2:-}"
	
    if [ -z "$_dest" ]; then \
		echo_error "Destination array for split_by not passed as second arg"
		return 1
	fi
	
    local _str="${3:-}"
	
    readarray -t -d '' "$_dest" < <(sed -z "s/$_sep/\x00/g" < <(printf '%s' "$_str"))
	
    local _transform="${4:-}"

	if [ -n "$_transform" ]; then
		local -n target_array="$_dest"
		for _indx in "${!target_array[@]}"; do
    		target_array[_indx]="$("$_transform" "${target_array[_indx]}")"
		done
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_dot() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by '.' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_comma() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by ',' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_space() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by ' ' "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}

# shellcheck disable=SC2329
function split_by_new_line() {
	local _dest="${1:-}"
	local _str="${2:-}"
	local _transform="${3:-}"
	if ! split_by "$CONST_NEW_LINE" "$_dest" "$_str" "$_transform"; then
		return 1
	fi

	return 0
}
