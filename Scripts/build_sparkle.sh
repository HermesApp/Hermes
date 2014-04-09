#!/bin/bash

# Exit on error
set -e
# Error on unbound variable access
set -u

information() {
    tput setaf 2
    printf '>>> INFO:  '
    tput sgr0
    printf '%s\n' "$*"
}

error() {
    tput setaf 1
    printf '>>> ERROR: '
    tput sgr0
    printf '%s\n' "$*"
    exit 1
}

# Ensure build target is called correctly.
check_environment() {
    if [ "$ACTION" = "clean" ]; then
        exit 0
    fi
    if [ "$CONFIGURATION" != "Release" ]; then
        error Distribution target requires "'Release'" build style
    fi
}

build_archive() {
    information "Building archive ($ARCHIVE_FILENAME)"
    cd "$BUILT_PRODUCTS_DIR"
    rm -f "$PROJECT_NAME"*.zip
    ditto -ck --keepParent "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app" "$ARCHIVE_FILENAME"
    SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
    PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
}

# This also verifies the signature.
sign_and_verify() {
    information "Signing for Sparkle distribution"
    cd "$BUILT_PRODUCTS_DIR"
    SIGNATURE=$("$SCRIPTS_DIR/sign_sparkle_release.sh" "$HOME/Documents/hermes.key" "$ARCHIVE_FILENAME")
    if [ "$SIGNATURE" = '' ]; then
        error 'Signing failed. Aborting.'
    fi
    if ! "$SCRIPTS_DIR/verify_sparkle_signature.sh" "$PROJECT_DIR/Resources/dsa_pub.pem" \
        "$SIGNATURE" "$ARCHIVE_FILENAME" >/dev/null
        then

        error 'Sparkle DSA signature verification FAILED. Aborting.'
    fi
}

build_versions_fragment() {
    information 'Building versions.xml fragment'
    cd "$BUILT_PRODUCTS_DIR"
    cat > versions.xml <<EOF
<item>
<title>Version $VERSION</title>
<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
<sparkle:minimumSystemVersion>10.6</sparkle:minimumSystemVersion>
<pubDate>$PUBDATE</pubDate>
<enclosure
url="$DOWNLOAD_URL"
sparkle:version="$INT_VERSION"
sparkle:shortVersionString="$VERSION"
type="application/octet-stream"
length="$SIZE"
sparkle:dsaSignature="$SIGNATURE"
/>
</item>
EOF
}

update_website() {
    information "Updating website in $HERMES_PAGES"
    cd "$BUILT_PRODUCTS_DIR"
    # Log the command
    set -x
    ruby $HERMES_PAGES/_config/release.rb \
        "$VERSION" \
        "$PWD/versions.xml" \
        "$PROJECT_DIR/CHANGELOG.md"
    # Stop logging
    set +x
}

upload_release() {
    information "Uploading $ARCHIVE_FILENAME to $DOWNLOAD_URL"
    cd "$BUILT_PRODUCTS_DIR"

    s3cmd put --acl-public "$ARCHIVE_FILENAME" "s3://alexcrichton-hermes/$ARCHIVE_FILENAME"
}

########################################
# Set up environment.
#
# Do not run the above shell functions
# until next comment.
########################################

check_environment

SCRIPTS_DIR="$PROJECT_DIR/Scripts"
APPLICATION="$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app"

INFO_PLIST="$APPLICATION/Contents/Info.plist"
VERSION=$(defaults read "$INFO_PLIST" CFBundleShortVersionString)
INT_VERSION=$(defaults read "$INFO_PLIST" CFBundleVersion)
ARCHIVE_FILENAME="$PROJECT_NAME-$VERSION.zip"

HERMES_PAGES="$(dirname $SOURCE_ROOT)/hermes-pages"
DOWNLOAD_URL="https://s3.amazonaws.com/alexcrichton-hermes/$ARCHIVE_FILENAME"
RELEASENOTES_URL="http://hermesapp.org/changelog.html"

########################################
# Execute the script
########################################

build_archive
sign_and_verify
build_versions_fragment
update_website
upload_release
