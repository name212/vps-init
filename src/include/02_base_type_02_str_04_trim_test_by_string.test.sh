#!/usr/bin/env bash

set -Eeuo pipefail

export __PRIVATE_TEST_TRIM_STRING_RES="true"

function __run_tests_trim_by_string() {
    function __test_trim_by_string() {
        local fun="$1"
        local symbol="$2"
        local count="$3"
        local str="$4"
        local should="$5"

        # shellcheck disable=SC2155
        local res="$("$fun" "$symbol" "$count" "$str")"

        local pass="${CONST_COLOR_RED}FAIL${CONST_COLOR_NO}"
        if [[ "$res" == "$should" ]]; then
            pass="${CONST_COLOR_GREEN}OK${CONST_COLOR_NO}"
        else
            __PRIVATE_TEST_TRIM_STRING_RES="false"
        fi 

        cat << EO_TST
${pass}: ${CONST_COLOR_GRAY_LIGHT}${fun}${CONST_COLOR_NO} $symbol ${count} ${CONST_COLOR_YELLOW}${str}${CONST_COLOR_NO}
  Should: ${CONST_COLOR_GREEN}${should}${CONST_COLOR_NO}
  Res: ${CONST_COLOR_GREEN}${res}${CONST_COLOR_NO}
EO_TST
    }

    local single_quote="'"
    local star="*"

    echo "Test trim_by_string_left:"

    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "0" \
        "${single_quote}count str" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "1" \
        "${single_quote}count str" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "0" \
        "${single_quote}${single_quote}count str" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "1" \
        "${single_quote}${single_quote}count str" \
        "${single_quote}count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "2" \
        "${single_quote}${single_quote}count str" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "3" \
        "${single_quote}${single_quote}count str" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "2" \
        "${single_quote}a${single_quote}count str" \
        "a${single_quote}count str"

    echo ""
    # regexp escape cases
    __test_trim_by_string \
        "trim_by_string_left" \
        "$star" \
        "0" \
        "${star}${star}count str${star}${star}" \
        "count str${star}${star}"

    echo ""
    
    # multi-symbols cases
    local multi_symbol="a-b-c"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$multi_symbol" \
        "0" \
        "${multi_symbol}${multi_symbol}${multi_symbol}count str ${multi_symbol}" \
        "count str a-b-c"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$multi_symbol" \
        "1" \
        "${multi_symbol}${multi_symbol}${multi_symbol}count str ${multi_symbol}" \
        "${multi_symbol}${multi_symbol}count str ${multi_symbol}"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$multi_symbol" \
        "2" \
        "${multi_symbol}${multi_symbol}${multi_symbol}count str ${multi_symbol}" \
        "${multi_symbol}count str ${multi_symbol}"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$multi_symbol" \
        "3" \
        "${multi_symbol}${multi_symbol}${multi_symbol}count str ${multi_symbol}" \
        "count str ${multi_symbol}"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$multi_symbol" \
        "10" \
        "${multi_symbol}${multi_symbol}${multi_symbol}count str ${multi_symbol}" \
        "count str ${multi_symbol}"

    echo ""
    echo "Test: trim_by_string_right"

    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "0" \
        "count str${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "1" \
        "count str${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "0" \
        "count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "1" \
        "count str${single_quote}${single_quote}" \
        "count str${single_quote}"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "2" \
        "count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "3" \
        "${single_quote}${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "${single_quote}${single_quote}${single_quote}count str"

    echo ""

    __test_trim_by_string \
        "trim_by_string_right" \
        "$star" \
        "0" \
        "**count str**" \
        "**count str"

    echo ""

    # multi-symbols cases with re-escape
    local multi_symbol_esc="a.b.c"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$multi_symbol_esc" \
        "0" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "${multi_symbol_esc}count str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$multi_symbol_esc" \
        "1" \
        "${multi_symbol_esc}${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "${multi_symbol_esc}${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$multi_symbol_esc" \
        "2" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "${multi_symbol_esc}count str${multi_symbol_esc}"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$multi_symbol_esc" \
        "4" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "${multi_symbol_esc}count str"

    echo ""

    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "0" \
        "${single_quote}count str${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "1" \
        "${single_quote}count str${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "0" \
        "${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "1" \
        "${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "${single_quote}count str${single_quote}"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "2" \
        "${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "3" \
        "${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "2" \
        "${single_quote}c${single_quote}${single_quote}count str${single_quote}a${single_quote}${single_quote}" \
        "c${single_quote}${single_quote}count str${single_quote}a"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "0" \
        "${single_quote}${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "2" \
        "${single_quote}${single_quote}${single_quote}count str${single_quote}${single_quote}" \
        "${single_quote}count str"

    echo ""

    __test_trim_by_string \
        "trim_by_string" \
        "$star" \
        "0" \
        "${star}${star}count str${star}${star}" \
        "count str"

    echo ""
    
    __test_trim_by_string \
        "trim_by_string" \
        "$multi_symbol_esc" \
        "0" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "count str"
    __test_trim_by_string \
        "trim_by_string" \
        "$multi_symbol_esc" \
        "1" \
        "${multi_symbol_esc}${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}"
    __test_trim_by_string \
        "trim_by_string" \
        "$multi_symbol_esc" \
        "2" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "count str${multi_symbol_esc}"
    __test_trim_by_string \
        "trim_by_string" \
        "$multi_symbol_esc" \
        "4" \
        "${multi_symbol_esc}count str${multi_symbol_esc}${multi_symbol_esc}${multi_symbol_esc}" \
        "count str"

    echo ""

    # no trim
    local same_str="count ${single_quote}i${single_quote} str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "0" \
        "$same_str" \
        "$same_str"
    __test_trim_by_string \
        "trim_by_string_left" \
        "$single_quote" \
        "1" \
        "$same_str" \
        "$same_str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "0" \
        "$same_str" \
        "$same_str"
    __test_trim_by_string \
        "trim_by_string_right" \
        "$single_quote" \
        "1" \
        "$same_str" \
        "$same_str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "0" \
        "$same_str" \
        "$same_str"
    __test_trim_by_string \
        "trim_by_string" \
        "$single_quote" \
        "1" \
        "$same_str" \
        "$same_str"

    echo ""

    function __test_trim_by_string_wrap() {
        local str="$1"
        local should="$2"

        # shellcheck disable=SC2155
        local res="$(trim_string_wrapper "$str")"

        local pass="${CONST_COLOR_RED}FAIL${CONST_COLOR_NO}"
        if [[ "$res" == "$should" ]]; then
            pass="${CONST_COLOR_GREEN}OK${CONST_COLOR_NO}"
        else
            __PRIVATE_TEST_TRIM_STRING_RES="false"
        fi 

        cat << EO_TST_2
${pass}: ${CONST_COLOR_GRAY_LIGHT}trim_string_wrapper${CONST_COLOR_NO} ${CONST_COLOR_YELLOW}${str}${CONST_COLOR_NO}
  Should: ${CONST_COLOR_GREEN}${should}${CONST_COLOR_NO}
  Res: ${CONST_COLOR_GREEN}${res}${CONST_COLOR_NO}
EO_TST_2
    }

    # trim string wrap
    __test_trim_by_string_wrap '"count "inside" str"' 'count "inside" str'
    __test_trim_by_string_wrap '""count "inside" str"' '"count "inside" str'
    __test_trim_by_string_wrap '"count "inside" str""' 'count "inside" str"'
    __test_trim_by_string_wrap 'count "inside" str' 'count "inside" str'

    echo ""

    __test_trim_by_string_wrap "'count 'inside' str'" "count 'inside' str"
    __test_trim_by_string_wrap "'''count 'inside' str'" "''count 'inside' str"
    __test_trim_by_string_wrap "'count 'inside' str''" "count 'inside' str'"
    __test_trim_by_string_wrap "count 'inside' str" "count 'inside' str"

    if [[ "$__PRIVATE_TEST_TRIM_STRING_RES" == "true" ]]; then
        return 0
    fi

    echo_error "Trim by string tests FAILED"

    return 1
}

__run_tests_trim_by_string "$@"
exit $?
