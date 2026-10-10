#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2034
export CONST_PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS_VAL="__should_contains_spec_symbols__"

# shellcheck disable=SC2034
export PASSWORD_STR_MIN_LEN="12"
# shellcheck disable=SC2034
export PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS="$CONST_PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS_VAL"

# shellcheck disable=SC2329
function check_valid_password_enable_specials() { 
	PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS="$CONST_PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS_VAL"
}

# shellcheck disable=SC2329
function check_valid_password_disable_specials() { 
	PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS=""
}

# shellcheck disable=SC2329
function check_valid_password_set_min_symbols() {
	local num="$1"

	if ! num="$(is_number_positive "$num")"; then
		echo_error "Cannot set min password len. '$num' is not number or not positive"
		return 1
	fi

	PASSWORD_STR_MIN_LEN="$num"
	return 0
}

# shellcheck disable=SC2329
function check_valid_password_reset_min_symbols() {
	check_valid_password_set_min_symbols "12" || true
}

check_valid_password_enable_specials || true
check_valid_password_reset_min_symbols || true

# shellcheck disable=SC2329
function check_valid_password() {
    local val="$1"

    if [ -z "$val" ]; then
        echo_error "Password cannot be empty!"
        return 1
    fi

    local pass_len=""
    if ! pass_len="$(echo -n "$val" | wc -c)"; then
        echo_error "Cannot get count of password str"
        return 1
    fi

    if num_less_than "$pass_len" "$PASSWORD_STR_MIN_LEN"; then
        echo_error "Len of password should minimum $PASSWORD_STR_MIN_LEN symbols. Got $pass_len"
        return 1
    fi

    local -A symbols_to_check=()

    symbols_to_check["a-z"]="lower symbols"
    symbols_to_check["A-Z"]="upper symbols"
    symbols_to_check["0-9"]="numbers"

    if [[ "$PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS" == "$CONST_PASSWORD_STR_SHOULD_CONTAINS_SPECIAL_SYMBOLS_VAL" ]]; then
        local spec_syms='.|,\/?!;]:[*%$^@><#&~'
        spec_syms="$(escape_regexp_str "$spec_syms")"
        symbols_to_check["$spec_syms"]="special symbols '$spec_syms'"
    fi

    local res_err=""
    for re_syms in "${!symbols_to_check[@]}"; do
        local err_msg="${symbols_to_check["$re_syms"]}"
        local re="[$re_syms]+"

        if ! echo -n "$val" | grep -qP "$re"; then
            res_err="$(append_str_with_separator ", " "$res_err" "$err_msg")"
        fi
    done

    if [ -n "$res_err" ]; then
        echo_error "Password not contains next symbols types: $res_err"
        return 1
    fi

    echo -n "$val"
    return 0
}
