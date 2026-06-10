#!/usr/bin/env bash
set -euo pipefail

: "${CODESIGN_CERTIFICATE_BASE64:?CODESIGN_CERTIFICATE_BASE64 is required}"
: "${CODESIGN_CERTIFICATE_PASSWORD:?CODESIGN_CERTIFICATE_PASSWORD is required}"

KEYCHAIN_DIR="${RUNNER_TEMP:-/tmp}"
KEYCHAIN_PATH="$KEYCHAIN_DIR/hyperlayer-signing.keychain-db"
CERTIFICATE_PATH="$KEYCHAIN_DIR/hyperlayer-signing.p12"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

mkdir -p "$KEYCHAIN_DIR"
rm -f "$KEYCHAIN_PATH"
printf '%s' "$CODESIGN_CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$CODESIGN_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  >/dev/null

security list-keychains -d user -s "$KEYCHAIN_PATH"
security default-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" \
  >/dev/null

security find-certificate -c "HyperLayer Self-Signed Code Signing" "$KEYCHAIN_PATH" >/dev/null
echo "Imported HyperLayer signing certificate into $KEYCHAIN_PATH"
