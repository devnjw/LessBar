#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# An unnotarized build must be an explicit choice.
MODE="${1:-}"
if [[ "$MODE" != --notarize && "$MODE" != --preview ]]; then
  echo "Usage: SIGNING_IDENTITY=... [NOTARY_PROFILE=...] $0 --notarize|--preview" >&2
  exit 2
fi
: "${SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
if [[ "$MODE" == --notarize ]]; then
  : "${NOTARY_PROFILE:?Set the notarytool keychain profile name}"
fi

bash scripts/build-app.sh --universal
APP_PATH="$PWD/dist/Less Bar.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
RELEASE_DIR="$PWD/dist/release"
mkdir -p "$RELEASE_DIR"
STAGING_DIR="$(mktemp -d "$PWD/.build/release-stage.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

notarize() {
  local artifact="$1"
  local log="$2"
  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 20m --output-format plist > "$log"
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print status' "$log")" != Accepted ]]; then
    echo "Notarization was not accepted; inspect $log. Nothing has been published." >&2
    exit 1
  fi
}

if [[ "$MODE" == --notarize ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$STAGING_DIR/notary.zip"
  notarize "$STAGING_DIR/notary.zip" "$RELEASE_DIR/app-notarization.plist"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose "$APP_PATH"
fi

mkdir "$STAGING_DIR/dmg"
ditto "$APP_PATH" "$STAGING_DIR/dmg/Less Bar.app"
ln -s /Applications "$STAGING_DIR/dmg/Applications"
cp LICENSE "$STAGING_DIR/dmg/LICENSE.txt"
cp docs/INSTALL.txt "$STAGING_DIR/dmg/Install.txt"
SUFFIX=""
if [[ "$MODE" == --preview ]]; then SUFFIX="-unnotarized"; fi
DMG="$RELEASE_DIR/Less-Bar-$VERSION$SUFFIX-universal.dmg"
ZIP="$RELEASE_DIR/Less-Bar-$VERSION$SUFFIX-universal.zip"
hdiutil create -volname "Less Bar" -srcfolder "$STAGING_DIR/dmg" -format UDZO -ov "$DMG"
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
if [[ "$MODE" == --notarize ]]; then
  notarize "$DMG" "$RELEASE_DIR/dmg-notarization.plist"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP"
(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS.txt
)
echo "Release artifacts: $RELEASE_DIR"
