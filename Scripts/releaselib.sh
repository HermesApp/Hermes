# releaselib.sh
#
# Tools used to archive and release Hermes.

mytput() {
    if tput colors >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
        tput "$@"
    fi
}

information() {
    mytput setaf 2
    printf '>>> INFO: '
    mytput sgr0
    printf '%s\n' "$*"
}

error() {
    mytput setaf 1
    printf '>>> ERROR: '
    mytput sgr0
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

# Set up environment for the rest of the functions
set_environment() {
    SCRIPTS_DIR="$PROJECT_DIR/Scripts"
    APPLICATION="$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app"

    VERSION=$(cd "$PROJECT_DIR"; agvtool mvers -terse1)
    VERSION_IS_PRERELEASE=$([[ $VERSION =~ [^0-9.] ]] && echo true || echo false)
    INT_VERSION=$(cd "$PROJECT_DIR"; agvtool vers -terse)
    ARCHIVE_FILENAME="$PROJECT_NAME-$VERSION.zip"

    HERMES_PAGES="$(dirname $SOURCE_ROOT)/hermes-pages"
    DOWNLOAD_URL="https://github.com/HermesApp/Hermes/releases/download/v${VERSION}/${ARCHIVE_FILENAME}"
    RELEASENOTES_URL="http://hermesapp.org/changelog.html"
}

build_archive() {
    information "Building archive $BUILT_PRODUCTS_DIR/$ARCHIVE_FILENAME"
    cd "$BUILT_PRODUCTS_DIR"
    rm -f "$PROJECT_NAME"*.zip
    ditto -ck --keepParent "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app" "$ARCHIVE_FILENAME"
    SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
    PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
}

# This also verifies the signature.
sign_and_verify() {
    if [[ $VERSION_IS_PRERELEASE == true ]]; then
        information "Not signing for Sparkle distribution for prerelease version"
        return
    fi
    information "Signing for Sparkle distribution"
    cd "$BUILT_PRODUCTS_DIR"
    SIGNATURE=$("$SCRIPTS_DIR/sign_sparkle_release.sh" "$PROJECT_DIR/../hermes.key" "$ARCHIVE_FILENAME")
    if [ "$SIGNATURE" = '' ]; then
        error 'Signing failed. Aborting.'
    fi
    if ! "$SCRIPTS_DIR/verify_sparkle_signature.sh" "$PROJECT_DIR/Resources/dsa_pub.pem" \
        "$SIGNATURE" "$ARCHIVE_FILENAME" >/dev/null
        then

        error 'Sparkle DSA signature verification FAILED. Aborting.'
    fi
}

check_code_signature() {
    codesign --verify --verbose=4 "$APPLICATION" || error 'codesign failed. Aborting.'
    spctl -vv --assess "$APPLICATION" || error 'spctl failed. Aborting.'
}

build_versions_fragment() {
    if [[ $VERSION_IS_PRERELEASE == true ]]; then
        information "Not building versions.xml fragment for prerelease version"
        return
    fi
    information 'Building versions.xml fragment'
    cd "$BUILT_PRODUCTS_DIR"
    cat > versions.xml <<EOF

    <item>
        <title>Version $VERSION</title>
        <sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
        <sparkle:minimumSystemVersion>$MACOSX_DEPLOYMENT_TARGET</sparkle:minimumSystemVersion>
        <pubDate>$PUBDATE</pubDate>
        <enclosure url="$DOWNLOAD_URL"
            sparkle:version="$INT_VERSION" sparkle:shortVersionString="$VERSION"
            type="application/octet-stream" length="$SIZE" sparkle:dsaSignature="$SIGNATURE"/>
    </item>
EOF
}

update_website() {
    if [[ $VERSION_IS_PRERELEASE == true ]]; then
        information "Not updating website for prerelease version"
        return
    fi
    information "Updating website in $HERMES_PAGES"
    cd "$BUILT_PRODUCTS_DIR"
    # Log the command
    set -x
    ruby $HERMES_PAGES/_config/release.rb \
        "$VERSION" \
        "$PWD/versions.xml" \
        "$PROJECT_DIR/CHANGELOG.md" \
        "$MACOSX_DEPLOYMENT_TARGET"
    # Stop logging
    set +x
}

upload_release() {
    local releases_url release_json html_url upload_url
    information "Creating release for $VERSION"
    releases_url='https://api.github.com/repos/HermesApp/Hermes/releases?access_token='$GITHUB_ACCESS_TOKEN
    release_json=$(curl --data @- "$releases_url" <<EOF
    {
        "tag_name": "v$VERSION",
        "target_commitish": "master",
        "name": "v$VERSION",
        "body": "",
        "draft": true,
        "prerelease": $VERSION_IS_PRERELEASE
    }
EOF
    )
    html_url=$(python -c 'import sys; import json; print json.load(sys.stdin)["html_url"]' <<<$release_json)

    information "Uploading $ARCHIVE_FILENAME to GitHub"
    upload_url=$(python -c 'import sys; import json; print json.load(sys.stdin)["upload_url"]' <<<$release_json)
    upload_url=$(sed -e 's/{.*$//' <<<$upload_url)"?name=${ARCHIVE_FILENAME}&access_token=${GITHUB_ACCESS_TOKEN}"
    curl -H 'Content-Type: application/zip' --data-binary "@$BUILT_PRODUCTS_DIR/$ARCHIVE_FILENAME" "$upload_url"

    open "$html_url"
}