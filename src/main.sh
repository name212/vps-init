#!/usr/bin/env bash

set -Eeuo pipefail

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
        echo_red "Internal error: '$phase_func' func not declared for phase $phase!"
        return 1
    fi

    echo -n "$phase_func"
    return 0
}

# shellcheck disable=SC2120
function usage() {
    local init_msg="Init server."
    if [ -n "${INIT_MSG_HELP:-}" ]; then
        init_msg="$INIT_MSG_HELP"
    fi

    # shellcheck disable=SC2154
    echo "
Usage: $bin_name [phase PHASE_FOR_RUN | cmd CMD_FOR_RUN] [args...]
  $init_msg
  Global parameters
    --not-ask
      If passed will not ask user about actions.
      Env NOT_ASK=true for set.

    --config 'PATH'
      Path to config with envs to settings.
      Should be .env format
      Env CONFIG_PATH 
    
    -h|--help
      Show this message.
  
  If passed 'phase' as first arg and name of phase as second
  only run only one phase.
  Otherwise, run all phases. For disable some phase 
  you can use disable env variable (see phase params).  
  
  Phases for run in order:
"

    for p in "$@"; do
        local help_fun="phase_${p}_help"
        if ! declare -F "$help_fun" > /dev/null; then
            echo_red "Help function not found for phase $p"
            exit 1
        fi
        echo ""
        echo "  Phase $p"
        "$help_fun"
        echo "    $(disable_help "$p")"
    done

    if [[ "${#COMMANDS_LIST[@]}" == "0" ]]; then
        return 0
    fi

    echo ""

    echo "
  If passed 'cmd' as first argument and name os command as second
  will run command

  Commands available:
"
    for cm in "${COMMANDS_LIST[@]}"; do
        local cmd_help_fun="cmd_${cm}_help"
        if ! declare -F "$cmd_help_fun" > /dev/null; then
            echo_red "Help function not found for command $cm"
            exit 1
        fi
        echo ""
        echo "  Command $cm"
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
        echo_red "Command '$cmd_name' not found!"
        return 1
    fi

    local run_func="cmd_${cmd_name}_run"

    if ! declare -F "$run_func" > /dev/null; then
        echo_red "Run function $run_func for command $cmd_name not found!"
        return 1
    fi

    shift

    if ! "$run_func" "$@"; then
        echo_red "Command $cmd_name failed" 
        return 1
    fi

    return 0
}

function run_tests_func() {
    return 0
}

function main() {
    local -a not_ordered_phases=()

    for pi in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$pi" ]; then
            echo_error "Got empty phase name!"
            exit 1
        fi

        local phase_index="${PHASES_WITH_INDEX[$pi]}"
        local index_for_set=""
        if ! index_for_set="$(phase_change_order "$pi" "$phase_index")"; then
            exit 1
        fi

        if [ -z "$index_for_set" ]; then
            echo_error "Empty index for phase '$pi'"
            exit 1
        fi

        not_ordered_phases+=("${index_for_set}:${pi}")
    done

    local -a phases_sorted=()
    readarray -t phases_sorted < <(printf '%s\n' "${not_ordered_phases[@]}" | sort)

    local -a phases=()
    for ps in "${phases_sorted[@]}"; do
        local phase_to_add="${ps#*:}"
        local func_err=""
        if ! func_err="$(phase_run_func "$phase_to_add")"; then
            echo_red "$func_err"
            exit 1
        fi 
        phases+=("$phase_to_add")
    done

    local -a help_flags=("-h" "--help")

    for ha in "${help_flags[@]}"; do 
        if arg_flag_is_set "$ha" "" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@"; then
            usage "${phases[@]}"
            exit 0
        fi
    done

    local not_ask=""
    not_ask="$(parse_not_ask "$@")" || true

    local config=""

    if ! config="$(extract_argument "--config" "CONFIG_PATH" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_red "Passed config is incorrect: $config"
        exit 1
    fi

    if [ -n "$config" ]; then
        echo_green "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a
    fi

    local got_phase_to_run=""

    case "${1-}" in
        "phase")
            got_phase_to_run="${2-}"

            if [ -z "$got_phase_to_run" ]; then
                usage "${phases[@]}"
                echo_red "Phase not provided"
                exit 1
            fi
        
            if ! [[ -v PHASES_WITH_INDEX["$got_phase_to_run"] ]]; then
                usage "${phases[@]}"
                echo_red "Not found phase $got_phase_to_run"
                exit 1
            fi

            shift
            shift
        ;;

        "cmd")
            local got_command_to_run="${2-}"
            if [ -z "$got_command_to_run" ]; then
                usage "${phases[@]}"
                echo_red "Command not provided"
                exit 1
            fi

            shift
            shift

            if ! run_passed_command "$got_command_to_run" "$@"; then
                exit 1
            fi

            exit 0
        ;;

        "__tst")
            local tst_ret="255"
            if run_tests_func; then
                tst_ret="0"
            else 
                tst_ret="$?"
            fi
            echo_green "Ret code: $tst_ret"
            exit "$tst_ret"
    esac

    local -a phases_to_run=()

    if [ -z "$got_phase_to_run" ]; then
        for pp in "${phases[@]}"; do
            if phase_is_not_disabled "$pp"; then
                phases_to_run+=("$pp")
            else
                echo_yellow "Phase $pp is skipped!"
            fi
        done
    else
        phases_to_run=("$got_phase_to_run")
    fi

    if [[ "${#phases_to_run[@]}" == "0" ]]; then
        echo_red "No one phase to run found!"
        exit 1
    fi

    # shellcheck disable=SC2155
    local old_hostname="$(get_hostname)"

    echo_green "Have next phases for run: ${phases_to_run[*]}"
    if ! ask_user "Start init ${old_hostname} ?" "$not_ask"; then
        echo_red "Disallow start!"
        exit 1
    fi

    for ph in "${phases_to_run[@]}"; do
        local phase_run=""

        if ! phase_run="$(phase_run_func "$ph")"; then
            echo_red "$phase_run"
            exit 1
        fi 

        echo ""
        echo_green "Run phase ${ph} with func '$phase_run'..."

        if ! "$phase_run" "$@"; then
            echo_red "Phase $ph failed! Exit"
            exit 1
        fi
        
        echo_green "Phase ${ph} succeeded!"
        echo ""
    done

    # shellcheck disable=SC2155
    local new_hostname="$(get_hostname)"

    echo_green "Init server $old_hostname done! New hostname: $new_hostname"
    return 0
}

main "$@"
exit $?
