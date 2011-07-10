#!/bin/bash

set -o errexit

[ $BUILD_STYLE = Release ] || { echo Distribution target requires "'Release'" build style; false; }

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleShortVersionString)

ARCHIVE_FILENAME="$PROJECT_NAME-$VERSION.zip"
DOWNLOAD_URL="https://github.com/downloads/alexcrichton/hermes/$ARCHIVE_FILENAME"
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
| openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g' | perl -MXML::LibXML -e 'print XML::LibXML->new()->parse_file("-")->findvalue(q(//string[preceding-sibling::key[1] = "NOTE"]))') \
| openssl enc -base64
)

[ "$SIGNATURE" != "" ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

cat > versions.xml <<EOF
<item>
<title>Version $VERSION</title>
<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
<pubDate>$PUBDATE</pubDate>
<enclosure
url="$DOWNLOAD_URL"
sparkle:version="$VERSION"
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

cp $ARCHIVE_FILENAME $HOME/Desktop
