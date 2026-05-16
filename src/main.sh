#!/usr/bin/env bash

set -Eeuo pipefail

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
     echo "
Usage: $bin_name [--phase PHASE_FOR_RUN] [args...]
  Init server.
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
  
  If passed --phase only run only one phase.
  Otherwise, run all phases. For disable some phase 
  you can use disable env variable (see phase params).  
  
  Phases for run in order:
"

    for p in "$@"; do
        local help_fun="phase_${p}_help"
        if ! declare -F "$help_fun" > /dev/null; then
            echo_red "Help function not found for $p"
            exit 1
        fi
        echo ""
        echo "  Phase $p"
        "$help_fun"
        echo "    $(disable_help "$p")"
    done
}

function main() {
    local -a not_ordered_phases=()

    for pi in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$pi" ]; then
            echo_red "Got empty phase name!"
            exit 1
        fi
        not_ordered_phases+=("${PHASES_WITH_INDEX[$pi]}:${pi}")
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

    local got_phase_to_run=""

    if [[ "${1-}" == "phase" ]]; then
        got_phase_to_run="${2-}"
        if ! [[ -v PHASES_WITH_INDEX["$got_phase_to_run"] ]]; then
            usage "${phases[@]}"
            echo_red "Not found phase $got_phase_to_run"
            exit 1
        fi

        shift
        shift
    fi

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

    echo_green "Have next phases for run: ${phases_to_run[*]}"
    if ! ask_user "Start init?" "$not_ask"; then
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
        
        echo_green "Phase ${ph} successed!"
        echo ""
    done

    return 0
}

main "$@"
exit $?
