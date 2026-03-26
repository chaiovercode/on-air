#!/bin/bash

# Build and package OnAir for distribution
# Usage: ./build-release.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/OnAir.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
RELEASE_DIR="$BUILD_DIR/OnAir-Release"
ZIP_PATH="$BUILD_DIR/OnAir.zip"

echo ""
echo "==================================="
echo "  Building OnAir for distribution"
echo "==================================="
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo "[1/4] Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/OnAir.xcodeproj" \
    -scheme "OnAir" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    -quiet

# Step 2: Export the .app from the archive
echo "[2/4] Exporting app..."
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE_PATH/Products/Applications/OnAir.app" "$EXPORT_DIR/OnAir.app"

# Step 3: Bundle with installer
echo "[3/4] Packaging..."
mkdir -p "$RELEASE_DIR"
cp -R "$EXPORT_DIR/OnAir.app" "$RELEASE_DIR/"
cp "$PROJECT_DIR/install.command" "$RELEASE_DIR/"
chmod +x "$RELEASE_DIR/install.command"

# Step 4: Create zip
echo "[4/4] Creating zip..."
cd "$BUILD_DIR"
zip -r -q "OnAir.zip" "OnAir-Release"

SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "==================================="
echo "  Done!"
echo "==================================="
echo ""
echo "  Zip:    $ZIP_PATH"
echo "  SHA256: $SHA"
echo ""
