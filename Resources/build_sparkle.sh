#!/bin/bash

set -o errexit

[ "$ACTION" = "clean" ] && exit 0
[ "$CONFIGURATION" = "Release" ] || { echo Distribution target requires "'Release'" build style; false; }

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleShortVersionString)
INT_VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleVersion)

ARCHIVE_FILENAME="$PROJECT_NAME-$VERSION.zip"
DOWNLOAD_URL="https://s3.amazonaws.com/alexcrichton-hermes/$ARCHIVE_FILENAME"
RELEASENOTES_URL="http://alexcrichton.com/hermes/changelog.html"
KEYCHAIN_PRIVKEY_NAME="Hermes Sparkle Private Key"

WD=$PWD
cd "$BUILT_PRODUCTS_DIR"
rm -f "$PROJECT_NAME"*.zip
ditto -ck --keepParent "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")

SIGNATURE=$(
openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
| openssl dgst -dss1 -sign < $HOME/Dropbox/misc/hermes.key \
| openssl enc -base64
)

[ "$SIGNATURE" != "" ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

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

hermes_pages=$(dirname $SOURCE_ROOT)/hermes-pages
if [ -d $hermes_pages ]; then
  set -x
  ruby $hermes_pages/_config/release.rb \
    $VERSION \
    "`pwd`/versions.xml" \
    "$PROJECT_DIR/CHANGELOG.md"
  set +x
fi

s3cmd put --acl-public $ARCHIVE_FILENAME s3://alexcrichton-hermes/$ARCHIVE_FILENAME
