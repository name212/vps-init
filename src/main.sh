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

    for p in "${!PHASES_WITH_INDEX[@]}"; do
        if [ -z "$p" ]; then
            echo_red "Got empty phase name!"
            exit 1
        fi
        not_ordered_phases+=("${PHASES_WITH_INDEX[$p]}:${p}")
    done

    local -a phases_sorted=()
    readarray -t phases_sorted < <(printf '%s\n' "${not_ordered_phases[@]}" | sort)

    local -a phases=()
    for p in "${phases_sorted[@]}"; do
        local phase_to_add="${p#*:}"
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

    local phase_to_run=""

    if [[ "$1" == "phase" ]]; then
        phase_to_run="$2"
        if ! [[ -v PHASES_WITH_INDEX["$phase_to_run"] ]]; then
            usage "${phases[@]}"
            echo_red "Not found phase $phase_to_run"
            exit 1
        fi

        shift
        shift
    fi

    local config=""

    if ! config="$(arg_flag_is_set "--config" "CONFIG_PATH" "$CONST_NOT_FLAG" "validate_arg_not_empty_file" "$@")"; then
        echo_red "Passed config is incorrect: $config"
        exit 1
    fi

    if [ -n "$config" ]; then
        echo_green "Load config $config"
        # shellcheck disable=SC1090
        set -a && source "$config" && set +a
    fi

    local -a phases_to_run=()

    if [ -z "$phase_to_run" ]; then
        for p in "${phases[@]}"; do
            if phase_is_not_disabled "$p"; then
                phases_to_run+=("$p")
            else
                echo_yellow "Phase $p is skipped!"
            fi
        done
    else
        phases_to_run=("$phase_to_run")
    fi

    if [[ "${#phases_to_run[@]}" == "0" ]]; then
        echo_red "No one phase to run found!"
        exit 1
    fi

    for p in "${phases[@]}"; do
        local phase_run=""

        if ! phase_run="$(phase_run_func "$phase_to_add")"; then
            echo_red "$phase_run"
            exit 1
        fi 

        echo_green "Run phase ${p}..."

        if ! "$phase_run" "$@"; then
            echo_red "Phase $p failed! Exit"
            exit 1
        fi
        
        echo_green "Phase ${p} successed!"
    done

    return 0
}

main "$@"
exit $?
