#!/usr/bin/env bash

work_in_tempdir(){
    local _directory

    _directory="$(mktemp -d "/tmp/$__exec.XXXXXXXXXXXX")"
    trap_exit "rm -rf '$_directory'"

    cd "$_directory"
}
work_in_tempdir
