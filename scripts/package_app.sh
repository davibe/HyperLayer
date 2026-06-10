#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HyperLayer"
PROJECT_NAME="HyperLayer.xcodeproj"
SCHEME_NAME="HyperLayer"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build}"
DIST_DIR="${DIST_DIR:-dist}"
ZIP_BASENAME="${ZIP_BASENAME:-HyperLayer}"
APP_VERSION="${APP_VERSION:-}"
APP_BUILD="${APP_BUILD:-}"
CODE_SIGN_IDENTITY_OVERRIDE="${CODE_SIGN_IDENTITY:-}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

if [[ -z "$APP_VERSION" ]]; then
  if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then
    APP_VERSION="${GITHUB_REF_NAME:-${GITHUB_REF#refs/tags/}}"
    APP_VERSION="${APP_VERSION#v}"
  elif [[ "${GITHUB_REF_TYPE:-}" == "tag" && "${GITHUB_REF_NAME:-}" == v* ]]; then
    APP_VERSION="${GITHUB_REF_NAME#v}"
  fi
fi

if [[ -z "$APP_BUILD" && "$APP_VERSION" =~ ^[0-9]+[.][0-9]+[.]([0-9]+)$ ]]; then
  APP_BUILD="${BASH_REMATCH[1]}"
fi

XCODE_BUILD_SETTINGS=()
if [[ -n "$APP_VERSION" ]]; then
  XCODE_BUILD_SETTINGS+=("MARKETING_VERSION=$APP_VERSION")
fi
if [[ -n "$APP_BUILD" ]]; then
  XCODE_BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=$APP_BUILD")
fi
if [[ -n "$CODE_SIGN_IDENTITY_OVERRIDE" ]]; then
  XCODE_BUILD_SETTINGS+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY_OVERRIDE")
fi

xcodegen generate

if [[ ${#XCODE_BUILD_SETTINGS[@]} -gt 0 ]]; then
  xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "${XCODE_BUILD_SETTINGS[@]}" \
    build
else
  xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

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
