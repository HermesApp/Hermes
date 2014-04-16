#!/bin/sh

set -eu

. "$(dirname "$0")/releaselib.sh"

check_environment
set_environment

build_archive
