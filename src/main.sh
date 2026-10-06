#!/usr/bin/env bash

# start idempotent run
{

set -Eeuo pipefail

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

    # shellcheck disable=SC2155
    # shellcheck disable=SC2034
    local script_name="$(get_original_script_name)"
    
    # shellcheck disable=SC2154
    echo "Usage: $script_name [ [global parameters] phase PHASE_FOR_RUN | [global parameters] cmd CMD_FOR_RUN] [args...]"
    echo ""

    # shellcheck disable=SC2155
    local help_about_help="$(echo_help_args_help)"
    help_about_help="$(trim_spaces_left "$help_about_help")"

    echo_green "Global parameters:"
    echo "    $help_about_help
  $(config_file_help)
  $(not_ask_help)
  $(log_settings_help)
  $(screen_args_help)
"
    echo_green "Phases."
    echo_green "If passed 'phase' as first arg and name of phase as second"
    echo_green "  only run only one phase."
    echo_green "Otherwise, run all phases. For disable some phase"
    echo_green "  you can use disable env variable (see phase params)."
    echo_yellow "If you run one phase pass global parameters before 'phase' argument or use envs."
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
        echo "    $(phase_print_disable_help "$p")"
    done

    echo ""

    if [[ "${#COMMANDS_LIST[@]}" == "0" ]]; then
        echo_yellow "Not any commands found for run."
        return 0
    fi

    echo_green "Commands."
    echo_green "If passed 'cmd' as first argument and name as command as second will run command"
    echo_yellow "If you run cmd pass global parameters before 'cmd' argument or use envs."
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