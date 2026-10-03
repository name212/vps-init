#!/usr/bin/env bash

# start idempotent run
{

set -Eeuo pipefail

export CONST_PRIVATE_LIB_LOADED_VAL="__lib_loaded__"
export CONST_PRIVATE_SCRIPT_RERAN_VAL="__script_re_ran__"

function remove_idempotent_run_strings() {
    local content="$1"

    content="$(echo "$content" | sed "/${CONST_IDEMPOTENT_START_COMMENT}/,+1d")"
    content="$(echo "$content" | sed "/${CONST_IDEMPOTENT_END_COMMENT}/,+1d")"

    echo -n "$content"

    return 0
}

function load_lib() {
    if [[ "${CONST_PRIVATE_LIB_LOADED:-}" == "$CONST_PRIVATE_LIB_LOADED_VAL" ]]; then
        echo_debug "Lib already reloaded"
        return 0
    fi

    local lib_file="${WORKING_DIR}/${CONST_LIB_FILE_NAME}"
    if [ ! -s "$lib_file" ]; then
        echo_error "Lib file '$lib_file' not found or empty"
        return 1
    fi

    local lib_sum_all=""
    if ! lib_sum_all="$(sha256sum "$lib_file")"; then
        echo_error "Cannot calculate sha256sum for '$lib_file'"
        return 1
    fi

    local lib_sum=""
    if ! lib_sum="$(echo "$lib_sum_all" | cut -c -16)"; then
        echo_error "Cannot extract 16 symbols sum for '$lib_file' from ''"
        return 1
    fi

    echo_debug "Library sum is '$lib_sum'"

    local main_content=""
    if ! main_content="$(cat "$CONST_SCRIPT_NAME")"; then
        rm -f "$tmp_reloaded_script" || true
        echo_error "Cannot load main content from'$CONST_SCRIPT_NAME'"
        return 1
    fi

    local tmp_reloaded_script=""
    if ! tmp_reloaded_script="$(mktemp)"; then
        echo_error "tmp file for reload not found"
        return 1
    fi

    if ! chmod 755 "$tmp_reloaded_script"; then
        echo_error "Cannot chmod 755 $tmp_reloaded_script"
        return 1
    fi

    main_content="$(remove_idempotent_run_strings "$main_content")"
    
    write_shebang_header "$tmp_reloaded_script"

    # shellcheck disable=SC2129
    {
        echo "$CONST_IDEMPOTENT_START_COMMENT";
        echo "{";
        echo "";
    } >> "$tmp_reloaded_script"

    cat "$lib_file" >> "$tmp_reloaded_script"
    echo "$main_content" >> "$tmp_reloaded_script"

    # shellcheck disable=SC2129
    {
        echo "$CONST_IDEMPOTENT_END_COMMENT";
        echo "}";
        echo "";
    } >> "$tmp_reloaded_script"

    if ! mv "$tmp_reloaded_script" "$CONST_SCRIPT_NAME"; then
        echo_error "Cannot replace script from '$tmp_reloaded_script' '$CONST_SCRIPT_NAME'"
        return 1
    fi

    return 0
}

function enter_in_screen() {
    local enable_screen="$CONST_SCREEN_SHOULD_REPLACED"
    local screen_records_dir=""
    local screen_sess_name=""

    if ! parse_screen_args "enable_screen" "screen_records_dir" "screen_sess_name" "$@"; then
        echo_error "Cannot parse screen arguments"
        return 1
    fi

    echo_debug "Screen enabled: $enable_screen"
    echo_debug "Screen record dir: $screen_records_dir"
    echo_debug "Screen session name prefix: $screen_sess_name"

     if [[ "$enable_screen" == "$CONST_SCREEN_SHOULD_REPLACED" ]]; then
        if ! screen_replace_run_with_screen "$enable_screen" "$screen_sess_name" "$screen_records_dir" "" "$@"; then
            echo_error "Cannot replace to run in screen"
            return 1
        fi
        return 0
    fi

    return 0

    # if [[ "${CONST_PRIVATE_SCRIPT_RERAN:-}" == "$CONST_PRIVATE_SCRIPT_RERAN_VAL" ]]; then
    #     echo_debug "Script already rerun"
    #     return 0
    # fi

    # local ret_code="0"

    # # shellcheck disable=SC2091
    # # shellcheck disable=SC2154
    # if $(exec "$CONST_SCRIPT_NAME" "$@"); then
    #     exit 0
    # else
    #     ret_code="$?"
    #     exit "$ret_code"
    # fi
}

function get_hostname() {
    local hst=""
    if ! hst="$(uname -n)"; then
        hst="host"
    fi

    echo -n "$hst"

    return 0
}

function phase_change_order() {
    local phase="$1"
    local cur_order="$2"

    local reorder_func="global_reorder_phase"

    if ! declare -F "$reorder_func" > /dev/null; then
        echo -n "$cur_order"
        return 0
    fi

    local new_order=""
    if ! new_order="$("$reorder_func" "$phase" "$cur_order")"; then
        echo_error "Cannot call '$reorder_func' to get order for phase '$phase'"
        return 1
    fi

    if [ -z "$new_order" ]; then
        echo_error "'$reorder_func' returned empty order for phase '$phase'"
        return 1
    fi

    echo -n "$new_order"
    return 0
}

function phase_run_func() {
    local phase="$1"

    local phase_func="phase_${phase}_run"

    if ! declare -F "$phase_func" > /dev/null; then
        echo_error "Internal error: '$phase_func' func not declared for phase '$phase'!"
        return 1
    fi

    echo -n "$phase_func"
    return 0
}

# shellcheck disable=SC2120
function usage() {
    local init_msg="Init ubuntu server."
    if [ -n "${INIT_MSG_HELP:-}" ]; then
        init_msg="$INIT_MSG_HELP"
    fi

    # shellcheck disable=SC2154
    echo "$init_msg"
    echo ""
    
    # shellcheck disable=SC2154
    echo "Usage: $CONST_SCRIPT_NAME [ [global parameters] phase PHASE_FOR_RUN | [global parameters] cmd CMD_FOR_RUN] [args...]"
    echo ""

    echo_green "  Global parameters:"
    echo "$(echo_help_args_help)

    --config 'PATH'
      Path to config with envs to settings.
      Should be .env format
      Env CONFIG_PATH 
    
    $(not_ask_help)
    $(log_settings_help)
    $(screen_args_help)
    
  If passed 'phase' as first arg and name of phase as second
  only run only one phase.
  Otherwise, run all phases. For disable some phase 
  you can use disable env variable (see phase params).  
  
  Phases.
"
    echo_green "  If you run one phase or cmd pass global parameters before 'phase/cmd' argument or use envs"

    echo_green  "Phases for run in order:"

    for p in "$@"; do
        local help_fun="phase_${p}_help"
        if ! declare -F "$help_fun" > /dev/null; then
            echo_error "Help function not found for phase $p"
            exit 1
        fi
        echo ""
        echo -n "  Phase " 
        echo_yellow "$p"
        "$help_fun"
        echo "    $(disable_help "$p")"
    done

    echo ""

    if [[ "${#COMMANDS_LIST[@]}" == "0" ]]; then
        echo_yellow "Not any commands found for run."
        return 0
    fi

    echo "
  If passed 'cmd' as first argument and name os command as second
  will run command

"
    echo_green "Commands available:"

    for cm in "${COMMANDS_LIST[@]}"; do
        local cmd_help_fun="cmd_${cm}_help"
        if ! declare -F "$cmd_help_fun" > /dev/null; then
            echo_error "Help function not found for command $cm"
            exit 1
        fi
        echo ""
        echo -n "  Command " 
        echo_yellow "$cm"
        "$cmd_help_fun"
    done
}

function run_passed_command() {
    local cmd_name="${1-}"
    
    local found=""
    for cmd in "${COMMANDS_LIST[@]}"; do
        if [[ "$cmd_name" == "$cmd" ]]; then
            found="true"
            break
        fi
    done

    if [[ "$found" != "true" ]]; then
        echo_error "Command '$cmd_name' not found!"
        return 1
    fi

    local run_func="cmd_${cmd_name}_run"

    if ! declare -F "$run_func" > /dev/null; then
        echo_error "Run function $run_func for command $cmd_name not found!"
        return 1
    fi

    shift

    if ! "$run_func" "$@"; then
        echo_error "Command $cmd_name failed" 
        return 1
    fi

    return 0
}

function parse_and_apply_config_file() {
    if is_help_flag_set "$@"; then
        return 0
    fi

    local config=""

    if ! config="$(extract_argument "--config" "CONFIG_PATH" "$CONST_NOT_FLAG" "validate_arg_not_empty_file_optional" "$@")"; then
        echo_error "Passed config is incorrect: $config"
        return 1
    fi

    if [ -n "$config" ]; then
        echo_info "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a

        if declare -F "set_passed_config_file" > /dev/null; then
            set_passed_config_file "$config"
        fi
    fi
}

function main() {
    if ! parse_and_apply_config_file "$@"; then
        echo_error "Cannot apply config"
        return 1
    fi

    if ! is_help_flag_set "$@"; then
        if ! parse_and_apply_log_settings "$@"; then
            echo_error "Cannot apply log settings"
            return 1
        fi
    fi

    if ! enter_in_screen "$@"; then
        echo_error "Cannot restart script"
        return 1
    fi

    print_debug_log_file

    local -a not_ordered_phases=()

    for pi in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$pi" ]; then
            echo_error "Got empty phase name!"
            return 1
        fi

        local phase_index="${PHASES_WITH_INDEX[$pi]}"
        local index_for_set=""
        if ! index_for_set="$(phase_change_order "$pi" "$phase_index")"; then
            return 1
        fi

        if [ -z "$index_for_set" ]; then
            echo_error "Empty index for phase '$pi'"
            return 1
        fi

        not_ordered_phases+=("${index_for_set}:${pi}")
    done

    local -a phases_sorted=()
    readarray -t phases_sorted < <(printf '%s\n' "${not_ordered_phases[@]}" | sort -n)

    local -a phases=()
    for ps in "${phases_sorted[@]}"; do
        local phase_to_add="${ps#*:}"
        local func_err=""
        if ! func_err="$(phase_run_func "$phase_to_add")"; then
            echo_error "$func_err"
            return 1
        fi 
        phases+=("$phase_to_add")
    done

    if is_help_flag_set "$@"; then
        usage "${phases[@]}"
        return 0
    fi

    local not_ask=""
    not_ask="$(parse_not_ask "$@")" || true

    local got_run_one_phase=""
    local got_run_cmd=""

    local -a args_to_pass=()

    while [[ $# -gt 0 ]]; do
        local got_arg="${1}"
        shift

        if [[ "$got_arg" == "phase" ]]; then
            got_run_one_phase="${1-}"
            if [ -z "$got_run_one_phase" ]; then
                usage "${phases[@]}"
                echo_error "Pass 'phase' arg without phase"
                return 1
            fi

            if ! [[ -v PHASES_WITH_INDEX["$got_run_one_phase"] ]]; then
                usage "${phases[@]}"
                echo_error "Not found phase $got_run_one_phase"
                return 1
            fi

            shift

            args_to_pass=()
            continue
        elif [[ "$got_arg" == "cmd" ]]; then
            got_run_cmd="${1-}"
            if [ -z "$got_run_cmd" ]; then
                usage "${phases[@]}"
                echo_error "Pass 'cmd' arg without cmd name"
                return 1
            fi

            shift

            args_to_pass=()
            continue
        fi
        args_to_pass+=("$got_arg")
    done

    if [[ "$got_run_one_phase" != "" || "$got_run_cmd" != ""  ]]; then
        if [[ "$not_ask" == "$CONST_NOT_ASK_VAL" ]]; then
            args_to_pass+=("$CONST_NOT_ASK_ARG")
        fi
    fi

    if [[ "$got_run_cmd" != "" ]]; then
        if ! run_passed_command "$got_run_cmd" "${args_to_pass[@]}"; then
            return 1
        fi

        return 0
    fi

    local -a phases_to_run=()

    if [ -z "$got_run_one_phase" ]; then
        for pp in "${phases[@]}"; do
            if phase_is_not_disabled "$pp"; then
                phases_to_run+=("$pp")
            else
                echo_warn "Phase $pp is skipped!"
            fi
        done
    else
        phases_to_run=("$got_run_one_phase")
    fi

    if [[ "${#phases_to_run[@]}" == "0" ]]; then
        echo_error "No one phase to run found!"
        return 1
    fi

    # shellcheck disable=SC2155
    local old_hostname="$(get_hostname)"

    echo_info "Have next phases for run:"
    for ph_p in "${phases_to_run[@]}"; do
        echo_info "  $ph_p"
    done
    if ! ask_user "Start init '${old_hostname}'?" "$not_ask"; then
        echo_error "Disallow start!"
        return 1
    fi

    for ph in "${phases_to_run[@]}"; do
        local phase_run=""

        if ! phase_run="$(phase_run_func "$ph")"; then
            echo_error "$phase_run"
            return 1
        fi 

        echo ""
        echo_info "Run phase ${ph} with func '$phase_run'..."

        if ! "$phase_run" "${args_to_pass[@]}"; then
            echo_error "Phase $ph failed! Exit"
            return 1
        fi
        
        echo_info "Phase ${ph} succeeded!"
        echo ""
    done

    # shellcheck disable=SC2155
    local new_hostname="$(get_hostname)"

    echo_green "Init server $old_hostname done! New hostname: $new_hostname"
    return 0
}

main_exit_code="0"

if main "$@"; then
    true
else
    main_exit_code="$?"
    echo "${CONST_FAIL_MAIN_EXIT_CODE_PREFIX}${main_exit_code}"
fi

exit "$main_exit_code"

# end idempotent run
}