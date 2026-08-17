#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLOUD_SVG="$ROOT/Claudamangala/Resources/claude-logo.svg"
MENUBAR_SVG="$ROOT/Claudamangala/Resources/menubar-logo.svg"
APP_SVG="$ROOT/Claudamangala/Resources/app-icon.svg"
ICON_PACKAGE="$ROOT/Claudamangala/Claudamangala.icon"
ASSETS="$ROOT/Claudamangala/Assets.xcassets"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

mkdir -p "$ASSETS/MenuBarIcon.imageset" "$ASSETS/AppIcon.appiconset"

render() {
  local svg="$1"
  local size="$2"
  local out="$3"
  rsvg-convert -b none -w "$size" -h "$size" "$svg" -o "$out"
}

render "$MENUBAR_SVG" 18  "$ASSETS/MenuBarIcon.imageset/menubar@1x.png"
render "$MENUBAR_SVG" 36  "$ASSETS/MenuBarIcon.imageset/menubar@2x.png"
render "$MENUBAR_SVG" 54  "$ASSETS/MenuBarIcon.imageset/menubar@3x.png"

render "$APP_SVG" 16   "$ASSETS/AppIcon.appiconset/icon_16.png"
render "$APP_SVG" 32   "$ASSETS/AppIcon.appiconset/icon_32.png"
render "$APP_SVG" 64   "$ASSETS/AppIcon.appiconset/icon_64.png"
render "$APP_SVG" 128  "$ASSETS/AppIcon.appiconset/icon_128.png"
render "$APP_SVG" 256  "$ASSETS/AppIcon.appiconset/icon_256.png"
render "$APP_SVG" 512  "$ASSETS/AppIcon.appiconset/icon_512.png"
render "$APP_SVG" 1024 "$ASSETS/AppIcon.appiconset/icon_1024.png"

DOCS="$ROOT/docs"
mkdir -p "$DOCS/screenshots"
cp "$CLOUD_SVG" "$DOCS/claude-spark.svg"
cp "$ASSETS/AppIcon.appiconset/icon_512.png" "$DOCS/app-icon.png"
render "$MENUBAR_SVG" 144 "$DOCS/menubar-icon.png"

if ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool" && [ -x "$ICTOOL" ]; then
  "$ICTOOL" "$ICON_PACKAGE" --export-image --output-file /tmp/claudamangala-icon-check.png \
    --platform macOS --rendition Default --width 64 --height 64 --scale 1 >/dev/null \
    && echo "✓ Liquid Glass icon package validated with ictool"
else
  echo "⚠ ictool not found — skipped Claudamangala.icon validation"
fi

echo "✓ Icons generated in $ASSETS"
echo "✓ Docs assets synced to $DOCS"
