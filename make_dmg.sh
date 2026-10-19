#!/bin/zsh
set -e
cd "$(dirname "$0")"
./build.sh
APP=build/SoundSource.app
DMG=build/SoundSource.dmg
STAGE=build/dmg-stage
rm -rf "$STAGE" "$DMG"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "SoundSource" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Created $DMG"
