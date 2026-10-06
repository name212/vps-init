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