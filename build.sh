#!/bin/zsh
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/SoundSource.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/release/SoundSource "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources" build/AppIcon.iconset
swift tools/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP  (open with: open $APP)"
