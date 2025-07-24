#!/usr/bin/env bash
# ---
# install:
#   - wget

if ! wget -q --spider http://example.com; then
    exit 1
fi
