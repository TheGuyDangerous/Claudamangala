#!/usr/bin/env bash
# Capture README screenshots for Claudamangala.
# Requires: Accessibility + Screen Recording for Terminal (or run via osascript).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$ROOT/docs/screenshots"
APP="${APP_PATH:-$HOME/Library/Developer/Xcode/DerivedData/Claudamangala-*/Build/Products/Debug/Claudamangala.app}"

mkdir -p "$DOCS"

resolved_app=$(ls -d $APP 2>/dev/null | head -1 || true)
if [[ -z "$resolved_app" || ! -d "$resolved_app" ]]; then
  echo "Build the app first, or set APP_PATH to Claudamangala.app"
  exit 1
fi

capture_bounds() {
  local outfile="$1"
  local bounds
  bounds=$(osascript <<'APPLESCRIPT'
tell application "Claudamangala" to activate
tell application "System Events"
  tell process "Claudamangala"
    set frontmost to true
    if (count of windows) is 0 then
      click menu bar item "person.badge.key" of menu bar 2
      delay 0.8
    end if
    set w to first window
    set p to position of w
    set s to size of w
    return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
  end tell
end tell
APPLESCRIPT
)
  osascript -e "do shell script \"screencapture -x -R$bounds '$outfile'\""
  echo "✓ $outfile ($bounds)"
}

pkill -x Claudamangala 2>/dev/null || true
defaults delete com.sannidhya.claude com.sannidhya.claude.firebaseSession 2>/dev/null || true
open "$resolved_app"
sleep 2
capture_bounds "$DOCS/sign-in.png"

echo "Sign in from the menu bar, then press Enter to capture the accounts view."
read -r _
capture_bounds "$DOCS/accounts.png"
echo "Done."
