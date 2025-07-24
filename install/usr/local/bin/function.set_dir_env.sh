#!/usr/bin/env bash

set_dir_env(){
    if [[ "-$PWD" =~ "${DIRENV_DIR:-}" ]]; then
        return
    fi

    if [[ ! "${__set_dir_env__init:-}" ]]; then
        . ~/.asdf/asdf.sh
        export PATH="$PATH" DIRENV_LOG_FORMAT=
        direnv(){ asdf exec direnv "$@" ;}
        eval "$(asdf exec direnv hook bash)"
    fi
    __set_dir_env__init=1

    LC_ALL=C direnv status | grep -q 'allowed true' ||
        direnv allow
    _direnv_hook

    if required="$(grep '^python ' .tool-versions 2>/dev/null)"; then
        [[ "$(python --version)" = "${required^}" ]]
        ! command -v python pip | grep -v "$PWD/.direnv"
    fi
}
set_dir_env
