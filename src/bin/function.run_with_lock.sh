#!/usr/bin/env bash

run_with_lock(){
    local _lock _pid

    if [[ "$1" =~ ^(-l|--lock)$ ]]; then
        _lock="$2"
        shift 2
    else
        _lock="$__shm/$__exec.lock"
    fi

    if [[ -e "$_lock" ]]; then
        _pid="$(<"$_lock")"

        while [[ -e "$_lock" ]] && ps -o args= "$_pid" | grep -q "$__exec"; do
            sleep 1
        done
    else
        trap_exit "rm -f '$_lock'"
        echo "$$" >"$_lock"
        "$@"
        rm -f "$_lock"
    fi
}
run_with_lock "$@"
