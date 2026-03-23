#!/bin/bash
# Builds a release archive and creates a DMG for Homebrew Cask distribution.

set -euo pipefail

VERSION="${1:?Usage: build-release.sh <version>}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build/release"
APP_NAME="OnAir"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} v${VERSION}..."

cd "$PROJECT_DIR"
xcodegen generate

xcodebuild \
  -project OnAir.xcodeproj \
  -scheme OnAir \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}" \
  clean build

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: ${APP_PATH} not found"
  exit 1
fi

echo "==> Creating DMG..."
DMG_DIR="${BUILD_DIR}/dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

echo "==> DMG created: ${BUILD_DIR}/${DMG_NAME}"
echo "==> SHA256: $(shasum -a 256 "${BUILD_DIR}/${DMG_NAME}" | cut -d' ' -f1)"
