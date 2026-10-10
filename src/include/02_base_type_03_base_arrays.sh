#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function __get_array_type_str() { 
    local check_fun="$1"

    local type_str=""

    case "$check_fun" in

    "is_array_or_dict_var")
        type_str="array or dict"
    ;;
    
    "is_array_var")
        type_str="array"
    ;;

    "is_dict_var")
        type_str="dict"
    ;;

    *)
        type_str="\"array type not resolved for function '$check_fun'\""
    ;;

    esac

    echo -n "$type_str"
} 

# shellcheck disable=SC2329
function __get_array_dict_len() { 
    local check_type_fun="$1"
    local var_name="$2"

    if [ -z "$var_name" ]; then
        echo_error "var name not passed for get len"
        return 1
    fi

    if ! "$check_type_fun" "$var_name"; then
        # shellcheck disable=SC2155
        local type_str="$(__get_array_type_str "$check_type_fun")"
        echo_error "Variable '$var_name' is not $type_str for get len"

        return 1
    fi

    local -n __get_array_dict_len_target="$var_name"

    echo -n "${#__get_array_dict_len_target[@]}"

    return 0
}

# shellcheck disable=SC2329
function __is_array_dict_has_len() { 
    local check_type_fun="$1"
    local should_len="$2"
    local var_name="$3"

    if ! check_is_number "$should_len" > /dev/null; then
        echo_error "should len '$should_len' is not number"
        return 255
    fi


    local len_var=""
    if ! len_var="$(__get_array_dict_len "$check_type_fun" "$var_name")"; then
        return 255
    fi

    num_eq "$len_var" "$should_len"
    return $?
}

