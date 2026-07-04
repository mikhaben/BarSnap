#!/bin/bash

# BarSnap Deploy Script
# Builds the addon and deploys it to the local WoW AddOns folder

set -e

# Load local deploy config (WOW_ADDONS_DIR) — copy .env.example to .env
if [ -f .env ]; then
    set -a; . ./.env; set +a
fi

if [ -z "$WOW_ADDONS_DIR" ]; then
    echo "Error: WOW_ADDONS_DIR not set. Copy .env.example to .env and set your AddOns path."
    exit 1
fi
ADDONS_DIR="$WOW_ADDONS_DIR"
BUILD_DIR="build"
TOC_FILE=$(ls *.toc | head -1)
ADDON_NAME=$(grep "## Title:" "$TOC_FILE" | sed 's/.*Title: *//' | tr -d '\r\n\t')

# Verify the AddOns directory exists
if [ ! -d "$ADDONS_DIR" ]; then
    echo "Error: AddOns directory not found. Is the drive mounted?"
    echo "  $ADDONS_DIR"
    exit 1
fi

# Build
./build.sh

# Find the zip that was just created
ZIP_FILE=$(ls -t "${BUILD_DIR}"/*.zip 2>/dev/null | head -1)
if [ -z "$ZIP_FILE" ]; then
    echo "Error: No zip file found in ${BUILD_DIR}/"
    exit 1
fi

# Remove old addon from AddOns folder
echo "Removing old ${ADDON_NAME}..."
rm -rf "${ADDONS_DIR}/${ADDON_NAME}"

# Unzip into AddOns folder
echo "Deploying to WoW AddOns..."
unzip -qo "$ZIP_FILE" -d "$ADDONS_DIR"

echo "Deployed: ${ADDONS_DIR}/${ADDON_NAME}"
