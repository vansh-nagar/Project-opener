#!/usr/bin/env bash
# Builds ProjectOpener.app. Pass --install to also copy it to /Applications
# and relaunch it.
set -euo pipefail
cd "$(dirname "$0")"

APP="ProjectOpener.app"
BIN="ProjectOpener"

echo "==> Building (release)"
swift build -c release

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature keeps the app's identity stable across rebuilds, so macOS
# doesn't re-prompt for permissions.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "   (codesign skipped)"

if [[ "${1:-}" == "--install" ]]; then
  echo "==> Installing to /Applications"
  pkill -x "$BIN" 2>/dev/null || true
  sleep 0.3
  rm -rf "/Applications/$APP"
  cp -R "$APP" "/Applications/$APP"
  open "/Applications/$APP"
  echo "==> Running from /Applications"
else
  echo "==> Built ./$APP  (run ./build.sh --install to install + launch)"
fi
