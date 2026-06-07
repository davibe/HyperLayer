#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HyperLayer"
PROJECT_NAME="HyperLayer.xcodeproj"
SCHEME_NAME="HyperLayer"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build}"
DIST_DIR="${DIST_DIR:-dist}"
ZIP_BASENAME="${ZIP_BASENAME:-HyperLayer}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodegen generate

xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
ZIP_PATH="$DIST_DIR/$ZIP_BASENAME.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  shasum -a 256 "$ZIP_BASENAME.zip" > "$ZIP_BASENAME.zip.sha256"
)

echo "Packaged $APP_NAME $VERSION ($BUILD)"
echo "ZIP_PATH=$ZIP_PATH"
