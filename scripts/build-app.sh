#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ARGS=(-c release)
case "${1:-}" in
  --universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
  "") ;;
  *) echo "Usage: $0 [--universal]" >&2; exit 2 ;;
esac

swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
STAGING_DIR="$(mktemp -d "$PWD/.build/app-stage.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_PATH="$STAGING_DIR/Less Bar.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/LessBar" "$APP_PATH/Contents/MacOS/LessBar"
cp Resources/AppIcon.icns "$APP_PATH/Contents/Resources/"
cp Resources/Brand/LessBarMark.pdf "$APP_PATH/Contents/Resources/"
ditto "$BIN_DIR/LessBar_LessBar.bundle" "$APP_PATH/Contents/Resources/LessBar_LessBar.bundle"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
cp LICENSE "$APP_PATH/Contents/Resources/LICENSE.txt"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
else
  codesign --force --sign - "$APP_PATH"
fi
codesign --verify --deep --strict "$APP_PATH"
if [[ "${1:-}" == --universal ]]; then
  ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/LessBar")"
  [[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]]
fi
mkdir -p dist
# Replace only our generated bundle after validation succeeds.
rm -rf "dist/Less Bar.app" dist/LessBar.app
mv "$APP_PATH" "dist/Less Bar.app"
echo "Built: $PWD/dist/Less Bar.app"
