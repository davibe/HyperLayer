#!/usr/bin/env bash
set -euo pipefail

info_plist="${TARGET_BUILD_DIR:-}/${INFOPLIST_PATH:-}"
if [[ ! -f "$info_plist" ]]; then
  echo "Info.plist not found at $info_plist" >&2
  exit 1
fi

build_number="${HYPERLAYER_BUILD_NUMBER:-}"
repo_root="${SRCROOT:-}"

if [[ -z "$build_number" && -n "$repo_root" ]] && command -v git >/dev/null 2>&1; then
  if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    build_number="$(git -C "$repo_root" rev-list --count HEAD)"
  fi
fi

if [[ -z "$build_number" ]]; then
  build_number="${CURRENT_PROJECT_VERSION:-0}"
fi

if [[ ! "$build_number" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
  echo "Invalid build number: $build_number" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$info_plist"
echo "Stamped CFBundleVersion=$build_number"
