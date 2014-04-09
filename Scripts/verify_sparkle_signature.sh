#!/bin/sh
# From winny-/sparkle-util
# Install into $PATH as verify_sparkle_signature

set -e

: ${OPENSSL:='/usr/bin/openssl'}
DSA_PUBKEY="$1"
SIGNATURE="$2"
ZIPFILE="$3"
MKTEMP_TEMPLATE="validate_sparkle_signature.$$.XXXXXXXXX."

my_mktemp(){
    mktemp -t "${MKTEMP_TEMPLATE}${1}"
}

usage() {
    scriptname="$(basename "$0")"
    printf '%s DSA_PUBKEY SIGNATURE ZIPFILE\n' "$scriptname"
    echo 'Override environment variable OPENSSL to use different OpenSSL.'
    echo
    printf 'Example: %s public_dsa.pem "MCwCFGRnB0iQO97Nzf2Jaq1WIWh1Jym0AhRhfxNTjunEtMxar8naY5wEBvvEow==" my-app.zip\n' "$scriptname"
    exit 1
}

if [ $# -ne 3 ]; then
    usage
fi

DECODED_SIGNATURE_FILE="$(my_mktemp sigfile)"
ZIPFILE_SHA1_FILE="$(my_mktemp zipfile_sha1)"

echo "$SIGNATURE" | "$OPENSSL" enc -base64 -d > "$DECODED_SIGNATURE_FILE"
"$OPENSSL" dgst -sha1 -binary < "$ZIPFILE" > "$ZIPFILE_SHA1_FILE"
"$OPENSSL" dgst -dss1 -verify "$DSA_PUBKEY" -signature "$DECODED_SIGNATURE_FILE" "$ZIPFILE_SHA1_FILE"

rm -f "$DECODED_SIGNATURE_FILE" "$ZIPFILE_SHA1_FILE"
