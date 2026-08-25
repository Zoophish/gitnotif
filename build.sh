#!/bin/zsh
# Build GitNotif.app from the SwiftPM executable.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/GitNotif.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/GitNotif "$APP/Contents/MacOS/GitNotif"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so Keychain access works consistently across rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it:      open $APP"
echo "Install it:  cp -R $APP /Applications/"
