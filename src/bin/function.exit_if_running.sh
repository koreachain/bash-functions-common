#!/usr/bin/env bash

exit_if_running(){
    local _pidfile

    _pidfile="$__shm/$__exec.pid"

    if [[ -e "$_pidfile" ]] && \
            ps -o args= "$(<"$_pidfile")" | grep -q "$__exec"; then
        exit 0
    fi

    trap_exit "rm -f '$_pidfile'"
    echo "$$" >"$_pidfile"
}
exit_if_running
