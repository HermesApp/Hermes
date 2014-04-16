#!/bin/sh

set -eu

if [ "x$TERM" = "" ]; then
    TERM='vt100'
fi

. "$(dirname "$0")/releaselib.sh"

check_environment
set_environment

build_archive
sign_and_verify
build_versions_fragment
#update_website
#upload_release
