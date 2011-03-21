#!/bin/sh
source=`dirname $0`/build/Release

title=Hermes
applicationName=$title
size=20000
finalDMGName=$title

rm -f $finalDMGName.dmg
mkdir "$source/tmp"
cp -r $source/$title.app $source/tmp

hdiutil create -srcfolder "${source}/tmp" -volname "${title}" -fs HFS+ \
      -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${size}k pack.temp.dmg

device=$(hdiutil attach -readwrite -noverify -noautoopen "pack.temp.dmg" | \
         egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# backgrondPictureName=pandora.png
# mkdir /Volumes/"${title}"/.background
# cp $backgrondPictureName /Volumes/"${title}"/.background/

echo '
  tell application "Finder"
    tell disk "'${title}'"
          open
          set current view of container window to icon view
          set toolbar visible of container window to false
          set statusbar visible of container window to false
          set the bounds of container window to {400, 100, 885, 430}
          set theViewOptions to the icon view options of container window
          set arrangement of theViewOptions to not arranged
          set icon size of theViewOptions to 72
          #set background picture of theViewOptions to file ".background:'${backgroundPictureName}'"
          make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
          set position of item "'${applicationName}'" of container window to {100, 100}
          set position of item "Applications" of container window to {375, 100}
          update without registering applications
          delay 5
    end tell
  end tell
' | osascript

chmod -Rf go-w /Volumes/"${title}"
sync
sync
hdiutil detach ${device}
hdiutil convert "pack.temp.dmg" -format UDZO -imagekey zlib-level=9 -o "${finalDMGName}"
rm -f pack.temp.dmg
rm -rf $source/tmp