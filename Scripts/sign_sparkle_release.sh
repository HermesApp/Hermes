#!/bin/sh
# From winny-/sparkle-util
# Install into $PATH as sign_sparkle_release

set -e

: ${OPENSSL:='/usr/bin/openssl'}
DSA_PRIVKEY="$1"
RELEASE_ARCHIVE="$2"

usage() {
    scriptname="$(basename "$0")"
    printf 'Usage: %s DSA_PRIVKEY RELEASE_ARCHIVE\n' "$scriptname"
    echo 'Override environment variable OPENSSL to use different OpenSSL.'
    echo
    printf 'Example: %s dsa_privkey.pem Hermes-1.2.0.zip\n' "$scriptname"
    echo '(Private key usually ends with ".key" or ".pem")'
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

"$OPENSSL" dgst -sha1 -binary < "$RELEASE_ARCHIVE" \
| "$OPENSSL" dgst -dss1 -sign "$DSA_PRIVKEY" \
| "$OPENSSL" enc -base64
