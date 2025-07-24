#!/usr/bin/env bash

if [[ "$(id -u)" != 0 ]]; then
    print "$__exec must be run as root."
    exit 1
fi
