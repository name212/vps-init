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
