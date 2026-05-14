#!/usr/bin/env bash

set -Eeuo pipefail

bin_name="$0"

declare -A PHASES_WITH_INDEX=()
declare -A PHASES_HELP=()
declare -A PHASES_ACTION=()

function install_runner_and_deps() {
    local not_ask="$1"

    echo "Install runner and deps..."

    if ! install_base_packages; then 
        return 1
    fi    
    
    if ! install_docker; then 
        return 1
    fi

    if ! install_gitlab_runner "$not_ask"; then 
        return 1
    fi

    if ! install_werf "$not_ask"; then 
        return 1
    fi

    if ! install_flint "$not_ask"; then 
        return 1
    fi

    if ! add_aliases ; then 
        echo_red "Aliases not installed!"
        return 1
    fi

    echo "Runner and deps installed!"
}

function usage() {
     printf "
Usage: %s [optional-args...] -c|config PATH
Install gitlab runner and/or register gitlab runner

    -c|--config 'path to runner register config'
      Path to runner config. Required.

      Config should be .env format with next variables:
        GITLAB_RUNNER_URL   - url for runner
        GITLAB_RUNNER_TOKEN - runner token
        GITLAB_RUNNER_DESC  - runner description/name
        GITLAB_RUNNER_TAGS  - comma separated string with runner tags


    -o|--only-register
      If passed will not attempt to install runner and deps only register runner.


    -f|--not-ask
      If passed will not ask user about actions.
" "$bin_name"
}

function main() {
    local only_register=""
    local not_ask="false"
    local runner_config=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                runner_config="$2"
                shift
                shift
                ;;
            -f|--not-ask)
                not_ask="$CONST_NOT_ASK_VAL"
                shift # past argument
                ;;
            -o|--only-register)
                only_register="true"
                shift # past argument
                ;;
            -h|--help)
                usage
                exit 0
            ;;
        *)
            usage
            echo_red "Illegal option $1"
            exit 1
            ;;
        esac
    done

    if [ -z "$runner_config" ]; then
        usage
        echo_red "Runner config did not pass!"
        exit 1
    fi

    if [ ! -f "$runner_config" ]; then
        usage
        echo_red "Runner config $runner_config is not file!"
        exit 1
    fi

    if [ -z "$only_register" ]]; then
        if ! install_runner_and_deps "$not_ask"; then
            echo_red "Runner and deps not installed!"
            exit 1
        fi
    fi

    if ! register_gitlab_runner "$runner_config"; then
        echo_red "Runner not registered!"
        exit 1
    fi
}

main "$@"
