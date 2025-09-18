#!/usr/bin/env bash

make_temp(){
    local _prefix _file

    if [[ ! "${1:-}" =~ ^(fifo|page|temp)$ || ! "${2:-}" ]]; then
        print "Usage: ${BASH_SOURCE##*/} [fifo|page|temp] count"
        exit 1
    fi

    if [[ "$1" = temp ]]; then
        _prefix=/tmp
    else
        _prefix="$__shm"
    fi

    while read -r i; do
        _file="$(mktemp -u "$_prefix/$__exec.XXXXXXXXXXXX")"
        trap_exit "rm -f '$_file'"

        case "$1" in
            fifo)
                fifo["$i"]="$_file"
            ;;
            page)
                page["$i"]="$_file"
            ;;
            temp)
                temp["$i"]="$_file"
            ;;
        esac

        if [[ "$1" = fifo ]]; then
            mkfifo "$_file"
        fi
    done < <(seq "$2")
}
make_temp "$@"
