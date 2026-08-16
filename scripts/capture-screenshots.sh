#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$ROOT/docs/screenshots"
APP="${APP_PATH:-$HOME/Library/Developer/Xcode/DerivedData/Claudamangala-*/Build/Products/Debug/Claudamangala.app}"
OUT="$DOCS/app.png"
BUNDLE="com.sannidhya.claude"
STORAGE_KEY="com.sannidhya.claude.firebaseSession"

mkdir -p "$DOCS"

resolved_app=$(ls -d $APP 2>/dev/null | head -1 || true)
if [[ -z "$resolved_app" || ! -d "$resolved_app" ]]; then
  echo "Build the app first, or set APP_PATH to Claudamangala.app"
  exit 1
fi

if [[ -n "${CLAUDAMANGALA_EMAIL:-}" && -n "${CLAUDAMANGALA_PASSWORD:-}" ]]; then
  PLIST="$ROOT/Claudamangala/GoogleService-Info.plist"
  python3 <<PY
import json, plistlib, subprocess, urllib.request, os

with open("$PLIST", "rb") as f:
    api_key = plistlib.load(f)["API_KEY"]
email = os.environ["CLAUDAMANGALA_EMAIL"]
password = os.environ["CLAUDAMANGALA_PASSWORD"]

req = urllib.request.Request(
    f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}",
    data=json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req) as r:
    resp = json.load(r)

subprocess.run([
    "defaults", "write", "$BUNDLE", "$STORAGE_KEY", "-dict",
    "email", resp["email"],
    "refreshToken", resp["refreshToken"],
], check=True)
PY
fi

osascript <<'APPLESCRIPT'
tell application "System Events"
  repeat with p in (every application process whose visible is true)
    try
      if name of p is not in {"Claudamangala", "Finder"} then
        set visible of p to false
      end if
    end try
  end repeat
end tell
APPLESCRIPT

pkill -x Claudamangala 2>/dev/null || true
sleep 0.5
open "$resolved_app"
sleep 8

bounds=$(osascript <<'APPLESCRIPT'
tell application "Claudamangala" to activate
delay 0.3
tell application "System Events"
  tell process "Claudamangala"
    set frontmost to true
    if (count of windows) is 0 then
      click first menu bar item of menu bar 2
      delay 0.8
    end if
    delay 1.5
    set w to first window
    set p to position of w
    set s to size of w
    return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
  end tell
end tell
APPLESCRIPT
)

RAW="/tmp/claudamangala-screenshot-raw.png"
osascript -e "do shell script \"screencapture -x -R$bounds '$RAW'\""
swift "$ROOT/scripts/composite-screenshot.swift" "$RAW" "$OUT"
rm -f "$RAW"
echo "✓ $OUT ($bounds)"
