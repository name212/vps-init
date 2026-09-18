#!/usr/bin/env bash

set -Eeuo pipefail

function echo_red(){
    echo -e "\033[1;31m$1\033[0m" >&2
}

function echo_green (){
    echo -e "\033[1;32m$1\033[0m" >&2
}

function echo_yellow (){
    echo -e "\033[1;33m$1\033[0m" >&2
}