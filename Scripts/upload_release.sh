#!/bin/sh

set -eu

. "$(dirname "$0")/releaselib.sh"

check_environment
set_environment

build_archive
sign_and_verify
build_versions_fragment
update_website
upload_release
