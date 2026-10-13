#!/usr/bin/env bash

set -Eeuo pipefail

# shellcheck disable=SC2329
function is_dict_has_len() {
    local var_name="$1"
    local should_len="$2"

    __is_array_dict_has_len "is_dict_var" "$should_len" "$var_name"
    return $?
}

# shellcheck disable=SC2329
function is_dict_empty() {
    local var_name="$1"

    is_dict_has_len "$var_name" "0"
    return $?
}

# shellcheck disable=SC2329
function is_dict_has_key() {
    local var_name="$1"
    local key="$2"

    if ! is_dict_var "$var_name"; then
        echo_error "Variable '$var_name' is not dict"
        return 255
    fi

    local -n is_dict_has_key_dict="$var_name"

    if [[ -v is_dict_has_key_dict["$key"] ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function dict_get_val() {
    local var_name="$1"
    local key="$2"

    local ret_code="0"
    if is_dict_has_key "$var_name" "$key"; then
        local -n dict_get_key_dict="$var_name"
        echo -n "${dict_get_key_dict[$key]}"
        return 0
    else
        ret_code="$?"
        return "$ret_code"
    fi
}

# shellcheck disable=SC2329
function dict_get_diff() {
    local target_dict_name="$1"
    local new_dict_name="$2"
    local diff_dict_name="$3"
    local diff_deleted_arr_name="$4"

    if ! is_dict_var "$new_dict_name"; then
        echo_error "New dict name '$new_dict_name' is not dict"
        return 255
    fi

    if ! is_dict_var "$target_dict_name"; then
        echo_error "Target dict name '$target_dict_name' is not dict"
        return 255
    fi

    if ! is_dict_var "$diff_dict_name"; then
        echo_error "Diff destination dict name '$diff_dict_name' is not dict"
        return 255
    fi

    if ! is_array_var "$diff_deleted_arr_name"; then
        echo_error "Diff deleted keys destination array name '$diff_deleted_arr_name' is not array"
        return 255
    fi

    local -n get_diff_new_dict="$new_dict_name"
    local -n get_diff_target_dict="$target_dict_name"
    local -n get_diff_diff_dict="$diff_dict_name"
    local -n get_diff_diff_deleted_arr="$diff_deleted_arr_name"

    local has_diff="false"

    for key in "${!get_diff_new_dict[@]}"; do
        local val="${get_diff_new_dict[$key]}"
        local target_val=""
        if ! target_val="$(dict_get_val "$target_dict_name" "$key")"; then
            get_diff_diff_dict["$key"]="$val"
            has_diff="true"
            continue
        fi

        if [[ "$val" != "$target_val" ]]; then
            # shellcheck disable=SC2034
            get_diff_diff_dict["$key"]="$val"
            has_diff="true"
        fi
    done

    local del_indx="-1"
    for key_t in "${!get_diff_target_dict[@]}"; do
        if ! is_dict_has_key "$new_dict_name" "$key_t"; then
            ((del_indx++))
            # shellcheck disable=SC2034
            get_diff_diff_deleted_arr["$del_indx"]="$key_t"
            has_diff="true"
        fi
    done

    if [[ "$has_diff" == "true" ]]; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function dict_print_diff() { 
    local diff_dict_name="$1"
    local deleted_arr_name="$2"
    local echo_fun="${3:-echo}"
    local orig_dict_name="${4:-}"

    local -n dict_print_diff_diff_dict="$diff_dict_name" 
    local -n dict_print_diff_deleted_array="$deleted_arr_name"

    local -a added=() 
    local -a changed=() 

    for c_key in "${!dict_print_diff_diff_dict[@]}"; do
        c_val="${dict_print_diff_diff_dict[$c_key]}"
        
        local msg_ch="'$c_key': '$c_val'"
        if [ -n "$orig_dict_name" ]; then
            local origin_val=""
            if origin_val="$(dict_get_val "$orig_dict_name" "$c_key")"; then
                msg_ch="'$c_key': '$origin_val' -> '$c_val'"
            else
                added+=("'$c_key': '$c_val'")
                msg_ch=""
            fi
        fi

        if [ -n "$msg_ch" ]; then
            changed+=("$msg_ch")
        fi
    done

    if ! is_array_empty "added"; then
        "$echo_fun" "Added:"
        for ad_k in "${added[@]}"; do
            "$echo_fun" "  $ad_k"
        done
    fi

    if ! is_array_empty "changed"; then
        "$echo_fun" "Changed:"
        for ch_v in "${changed[@]}"; do
            "$echo_fun" "  $ch_v"
        done
    fi

    if ! is_array_empty "$deleted_arr_name"; then
        "$echo_fun" "Deleted:"
        for dk in "${dict_print_diff_deleted_array[@]}"; do
            "$echo_fun" "  '$dk'"
        done
    fi
}