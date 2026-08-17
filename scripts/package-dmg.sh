#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-}"
DMG_PATH="${2:-}"

if [ -z "$APP_PATH" ] || [ -z "$DMG_PATH" ]; then
  echo "Usage: $0 /path/to/Claudamangala.app /path/to/Claudamangala.dmg" >&2
  exit 1
fi

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
PAYLOAD="$STAGE/payload"
BG_PNG="$STAGE/background.png"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$PAYLOAD"
rsvg-convert -w 1320 -h 800 "$ROOT/dmg/background.svg" -o "$BG_PNG"
cp -R "$APP_PATH" "$PAYLOAD/Claudamangala.app"

rm -f "$DMG_PATH"
create-dmg \
  --volname "Claudamangala" \
  --background "$BG_PNG" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "Claudamangala.app" 165 185 \
  --hide-extension "Claudamangala.app" \
  --app-drop-link 495 185 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$PAYLOAD"
