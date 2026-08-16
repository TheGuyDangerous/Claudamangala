#!/usr/bin/env bash
# Rasterize SVG sources into the asset catalog PNGs.
# Requires: brew install librsvg  (rsvg-convert, transparent background)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MENUBAR_SVG="$ROOT/Claudamangala/Resources/claude-logo.svg"
APP_SVG="$ROOT/Claudamangala/Resources/app-icon.svg"
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

# Menu bar — transparent canvas, official Claude spark only
render "$MENUBAR_SVG" 18  "$ASSETS/MenuBarIcon.imageset/menubar@1x.png"
render "$MENUBAR_SVG" 36  "$ASSETS/MenuBarIcon.imageset/menubar@2x.png"
render "$MENUBAR_SVG" 54  "$ASSETS/MenuBarIcon.imageset/menubar@3x.png"

# macOS app icon sizes (includes dark rounded background in SVG)
render "$APP_SVG" 16   "$ASSETS/AppIcon.appiconset/icon_16.png"
render "$APP_SVG" 32   "$ASSETS/AppIcon.appiconset/icon_32.png"
render "$APP_SVG" 64   "$ASSETS/AppIcon.appiconset/icon_64.png"
render "$APP_SVG" 128  "$ASSETS/AppIcon.appiconset/icon_128.png"
render "$APP_SVG" 256  "$ASSETS/AppIcon.appiconset/icon_256.png"
render "$APP_SVG" 512  "$ASSETS/AppIcon.appiconset/icon_512.png"
render "$APP_SVG" 1024 "$ASSETS/AppIcon.appiconset/icon_1024.png"

DOCS="$ROOT/docs"
mkdir -p "$DOCS/screenshots"
cp "$MENUBAR_SVG" "$DOCS/claude-spark.svg"
cp "$ASSETS/AppIcon.appiconset/icon_512.png" "$DOCS/app-icon.png"
cp "$ASSETS/MenuBarIcon.imageset/menubar@3x.png" "$DOCS/menubar-icon.png"
swift "$ROOT/scripts/generate-banner.swift" "$ROOT"

echo "✓ Icons generated in $ASSETS"
echo "✓ Docs assets synced to $DOCS"
