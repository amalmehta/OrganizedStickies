#!/bin/zsh
# Build a Release copy, replace /Applications/Organized Stickies.app, and open it.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project OrganizedStickies.xcodeproj -scheme OrganizedStickies -configuration Release \
  -derivedDataPath build build | grep -E "error:|BUILD" || true
APP="build/Build/Products/Release/Organized Stickies.app"
[[ -d "$APP" ]] || { echo "Build failed"; exit 1; }
osascript -e 'quit app "Organized Stickies"' 2>/dev/null || true
while pgrep -f "Organized Stickies.app/Contents/MacOS" >/dev/null; do sleep 0.3; done
rm -rf "/Applications/Organized Stickies.app"
cp -R "$APP" /Applications/
open "/Applications/Organized Stickies.app" "$@"
echo "Installed /Applications/Organized Stickies.app"
