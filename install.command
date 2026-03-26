#!/bin/bash

# OnAir Installer
# Double-click this file to install OnAir

APP_NAME="OnAir.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/$APP_NAME"
APP_DEST="/Applications/$APP_NAME"

echo ""
echo "==================================="
echo "  OnAir Installer"
echo "==================================="
echo ""

# Check the app exists next to this script
if [ ! -d "$APP_SOURCE" ]; then
    echo "Error: $APP_NAME not found next to this installer."
    echo "Make sure $APP_NAME is in the same folder as this script."
    echo ""
    read -n 1 -s -r -p "Press any key to exit..."
    exit 1
fi

# Remove old version if present
if [ -d "$APP_DEST" ]; then
    echo "Removing previous version..."
    rm -rf "$APP_DEST"
fi

# Copy to Applications
echo "Installing to /Applications..."
cp -R "$APP_SOURCE" "$APP_DEST"

# Strip quarantine flag so Gatekeeper doesn't block it
echo "Clearing quarantine flag..."
xattr -cr "$APP_DEST"

echo ""
echo "Installed! Launching OnAir..."
echo ""

open "$APP_DEST"

read -n 1 -s -r -p "Press any key to close this window..."
