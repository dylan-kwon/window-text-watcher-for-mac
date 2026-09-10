#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/WindowTextWatcher.app"

cd "$ROOT_DIR"

swift build \
    -c release \
    --product WindowTextWatcher

BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cp "$BIN_DIR/WindowTextWatcher" \
    "$APP_DIR/Contents/MacOS/WindowTextWatcher"
cp "$ROOT_DIR/App/Info.plist" \
    "$APP_DIR/Contents/Info.plist"

SIGN_IDENTITY="${WINDOW_TEXT_WATCHER_SIGN_IDENTITY:-$(
    security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Apple Development:/ { print $2; exit }'
)}"

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing with: $SIGN_IDENTITY"
    codesign \
        --force \
        --deep \
        --timestamp=none \
        --sign "$SIGN_IDENTITY" \
        "$APP_DIR"
else
    echo "Warning: Apple Development signing identity not found."
    echo "Falling back to ad-hoc signing; macOS may forget Screen Recording permission after rebuilds."
    codesign \
        --force \
        --deep \
        --sign - \
        "$APP_DIR"
fi

echo "Built: $APP_DIR"
