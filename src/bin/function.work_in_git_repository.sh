#!/usr/bin/env bash
# ---
# install:
#   - git

work_in_git_repository(){
    local _pull _repository _directory

    if [[ "$1" = "--pull" ]]; then
        _pull=1
        shift
    fi

    if [[ ! "${1:-}" =~ / || ! "${2:-}" =~ / ]]; then
        print "Usage: ${BASH_SOURCE##*/} [--pull] repository directory"
        exit 1
    fi

    _repository="$1"
    _directory="$2"

    if [[ ! -d "$_directory" ]]; then
        git clone "$_repository" "$_directory"
    elif [[ "${_pull:-}" ]]; then
        git -C "$_directory" pull
    fi

    cd "$_directory"
}
. function.run_with_lock.sh -l "$__shm/$__exec.git.lock" \
    work_in_git_repository "$@"
