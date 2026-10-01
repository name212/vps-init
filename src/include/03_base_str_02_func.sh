#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_STR_TRIM_LEFT="__left__"
# shellcheck disable=SC2034
export CONST_STR_TRIM_RIGHT="__right__"

# shellcheck disable=SC2329
function escape_regexp_str() {
	local str="${1:-}"
	if [ -z "$str" ]; then
		echo -n ""
		return 0
	fi; \
	# shellcheck disable=SC2016
	# shellcheck disable=SC2155
	local escaped="$(printf '%s' "$str" | sed 's/[.[\*^$()+?{|]/\\&/g')"
	echo -n "$escaped"
	return 0
}

# shellcheck disable=SC2329
function trim_spaces_left() {
    local trimmed="${1:-}"
    echo -n "${trimmed#"${trimmed%%[![:space:]]*}"}"
	return 0
}

# shellcheck disable=SC2329
function trim_spaces_right() {
    local trimmed="${1:-}"
    echo -n "${trimmed%"${trimmed##*[![:space:]]}"}"
	return 0
}

# shellcheck disable=SC2329
function trim_spaces() {
    local trimmed="${1:-}"
    trimmed="$(trim_spaces_left "$trimmed")"
    trimmed="$(trim_spaces_right "$trimmed")"
    echo -n "$trimmed"
	return 0
}

# shellcheck disable=SC2329
function cut_left_bytes() {
	local str="$1"
	local num="${2}"
	num="$(("$num" + 1))-"
	# shellcheck disable=SC2155
	local res="$(echo -n "$str" | cut -b "$num")"
	echo -n "$res"
	return 0
}

# shellcheck disable=SC2329
function cut_right_bytes() {
	local str="$1"
	local num="${2}"
	# shellcheck disable=SC2155
	local bytes_to_trim="$(echo -n "$str" | wc -c)"
	num="-$(("$bytes_to_trim" - "$num"))"
	# shellcheck disable=SC2155
	local res="$(echo -n "$str" | cut -b "$num")"
	echo -n "$res"
	return 0
}

# shellcheck disable=SC2329
function __trim_by_string_on_side() {
	#set -x

	local symbol="${1:-}"
    local count="${2:-}"
    local side="${3}"
    local str_for_trim="${4:-}"

	if [[ "$symbol" == "" || "$str_for_trim" == "" ]]; then
		echo -n "$str_for_trim"
		set +x
		return 0
	fi

	# shellcheck disable=SC2034
	# shellcheck disable=SC2155
	local escaped_for_re="$(escape_regexp_str "$symbol")"

	local for_re="$escaped_for_re"
	if [[ "$count" == "" || "$count" == "0" ]]; then
		for_re="(($escaped_for_re)\\2{0,})"
	elif [[ "$count" != "1" ]]; then
		local last=$(("$count" - 1))
		for_re="(($escaped_for_re)\\2{0,$last})"
	fi

	local cut_fun=""

	if [[ "$side" == "$CONST_STR_TRIM_LEFT" ]]; then
		for_re="^${for_re}"
		cut_fun="cut_left_bytes"
	elif [[ "$side" == "$CONST_STR_TRIM_RIGHT" ]]; then
		for_re="${for_re}\$"
		cut_fun="cut_right_bytes"
	fi

	local matched_for_trim=""
	if matched_for_trim="$(echo -n "$str_for_trim" | grep -oP "$for_re")"; then
		# shellcheck disable=SC2155
		local bytes_to_trim="$(echo -n "$matched_for_trim" | wc -c)"
		# shellcheck disable=SC2155
		echo -n "$($cut_fun "$str_for_trim" "$bytes_to_trim")"
		return 0
	fi

	echo -n "$str_for_trim"
	set +x
	return 0
}

# shellcheck disable=SC2329
function trim_by_string_left() {
    local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	
	__trim_by_string_on_side "$symbol" "$count" "$CONST_STR_TRIM_LEFT" "$str"
	return $?
}

# shellcheck disable=SC2329
function trim_by_string_right() {
    local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	__trim_by_string_on_side "$symbol" "$count" "$CONST_STR_TRIM_RIGHT" "$str"
	return $?
}

# shellcheck disable=SC2329
function trim_by_string() {
	local symbol="${1}"
    local count="${2}"
    local str="${3:-}"

	# test cases


	# shellcheck disable=SC2155
	local res="$(trim_by_string_left "$symbol" "$count" "$str")"
	echo -n "$(trim_by_string_right "$symbol" "$count" "$res")"

	return 0
}

# shellcheck disable=SC2329
function trim_string_wrapper() {
    local str="${1:-}"

	local count="1"
	local -a symbols=('"' "'")

	local res="$str"
	for ss in "${symbols[@]}"; do
		res="$(trim_by_string "$ss" "$count" "$str")"
		if [[ "$res" != "$str" ]]; then
			break
		fi
	done

	echo -n "$res"

	return 0
}

# shellcheck disable=SC2329
function escape_new_line() {
	__escape_new_line "${1:-}"
	return 0
}

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

# shellcheck disable=SC2329
function rand_str_n() {
    if __rand_str_n "${1-1}"; then
		return 0
	else
		return "$?"
	fi
}