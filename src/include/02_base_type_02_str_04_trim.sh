#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_STR_TRIM_LEFT="__left__"
# shellcheck disable=SC2034
export CONST_STR_TRIM_RIGHT="__right__"

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
	local symbol="${1:-}"
    local count="${2:-}"
    local side="${3}"
    local str_for_trim="${4:-}"

	if [[ "$symbol" == "" || "$str_for_trim" == "" ]]; then
		echo -n "$str_for_trim"
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
