#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function num_great_than() {
	if [ "$1" -gt "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_less_than() {
	if [ "$1" -lt "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_great_eq() {
	if [ "$1" -ge "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function num_less_eq() {
	if [ "$1" -le "$2" ]; then
		return 0
	fi

	return 1
}

# shellcheck disable=SC2329
function check_is_number() {
    local val="$1"

    if ! [[ $val =~ ^-?[0-9]+$ ]]; then
        echo_error "'$val' is not number!"
        return 1
    fi

    echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function is_number_positive() {
    local val="$1"
    local have_zero="${2:-}"

    if ! val="$(check_is_number "$val")"; then
        return 1
    fi

    local err_num="1"
	local fun_check="num_great_than"

    if [ -n "$have_zero" ]; then
        err_num="0"
		fun_check="num_great_eq"
    fi

	if ! "$fun_check" "$val" "0"; then
    	echo_error "Number '$val' < $err_num"
		return 1
	fi

	echo -n "$val"
    return 0
}

# shellcheck disable=SC2329
function is_number_positive_or_zero() {
    is_number_positive "$1" "true"
    return $?
}
