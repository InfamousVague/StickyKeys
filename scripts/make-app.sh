#!/usr/bin/env bash
# Builds a release binary and assembles StickyKeys.app — a menu-bar agent
# (LSUIElement, no Dock icon) that locks the keyboard for cleaning.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/StickyKeys.app"
SRC_ICON="$ROOT/art/AppIcon-source.png"
VERSION="0.2.1"
# Same Developer ID as the sibling apps ("Matt Wisniewski, F6ZAL7ANAD").
# Override with SIGN_IDENTITY=- for an ad-hoc local build.
SIGN_IDENTITY="${SIGN_IDENTITY:-0948896DC970503ADEF5B5070E0BB3E9D9047757}"
DMG="$ROOT/StickyKeys-$VERSION.dmg"

echo "› swift build -c release"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

echo "› assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ICON_KEY=""
if [ -f "$SRC_ICON" ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
              "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
              "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; name="${spec##*:}"
    sips -z "$px" "$px" "$SRC_ICON" --out "$ICONSET/icon_${name}.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="  <key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cp "$BIN/StickyKeys" "$APP/Contents/MacOS/StickyKeys"

# ── Embed + (below) sign the SuiteKit contract and this
# app's pane dylib so the MattsSoftware launcher can load
# the SAME code out of this installed .app. rpath lets the
# bundled exe find them under Contents/Frameworks.
mkdir -p "$APP/Contents/Frameworks"
cp "$BIN/libSuiteKit.dylib" "$APP/Contents/Frameworks/"
cp "$BIN/libStickyKeysPane.dylib" "$APP/Contents/Frameworks/"
if [ -d "$BIN/StickyKeysPane_StickyKeysPane.bundle" ]; then cp -R "$BIN/StickyKeysPane_StickyKeysPane.bundle" "$APP/Contents/Frameworks/"; fi
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/StickyKeys" 2>/dev/null || true


cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>StickyKeys</string>
  <key>CFBundleDisplayName</key><string>StickyKeys</string>
  <key>CFBundleIdentifier</key><string>com.mattssoftware.stickykeys</string>
  <key>CFBundleExecutable</key><string>StickyKeys</string>
$ICON_KEY
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>StickyKeys</string>
</dict>
</plist>
PLIST

# Sign with the Developer ID (hardened runtime, distribution-ready).
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libSuiteKit.dylib"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libStickyKeysPane.dylib"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/StickyKeys"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP" && echo "✓ signed: $SIGN_IDENTITY"
else
  echo "⚠ signing identity $SIGN_IDENTITY not found — ad-hoc signing instead"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "✓ built $APP"

# Build a downloadable .dmg (StickyKeys.app + /Applications drop target).
STAGE="$(mktemp -d)/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/StickyKeys.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "StickyKeys" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG" || true
fi
echo "✓ built $DMG"

# Notarize + staple so downloads open without the Gatekeeper prompt.
# Skipped automatically for ad-hoc local builds (SIGN_IDENTITY=-).
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "› notarizing $DMG (this waits on Apple)…"
  xcrun notarytool submit "$DMG" \
    --keychain-profile "${NOTARY_PROFILE:-Notary}" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG" && echo "✓ notarized + stapled $DMG"
fi
