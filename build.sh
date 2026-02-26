#!/bin/bash

# BarSnap Build Script
# Creates a clean addon package for CurseForge upload

set -e

PROJECT_NAME="BarSnap"
BUILD_DIR="build"
TOC_FILE="${PROJECT_NAME}.toc"
STAGE_DIR="${BUILD_DIR}/${PROJECT_NAME}"
VERSION=$(grep "## Version:" "$TOC_FILE" | sed 's/.*Version: *//' | tr -d '\r\n\t ?')
TIMESTAMP=$(date -u +"%Y-%m-%d")
ZIP_NAME="${PROJECT_NAME}_${VERSION}_${TIMESTAMP}.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"
SEPARATOR="======================================"

echo "$SEPARATOR"
echo "Building ${PROJECT_NAME} v${VERSION}"
echo "Build date: ${TIMESTAMP}"
echo "$SEPARATOR"

# Create build directory
echo "Creating build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${STAGE_DIR}"

# Core addon files
echo "Copying addon files..."
cp "$TOC_FILE" Constants.lua Core.lua "${STAGE_DIR}/"

# Engine
echo "Copying Engine..."
cp -r Engine "${STAGE_DIR}/"

# UI
echo "Copying UI..."
cp -r UI "${STAGE_DIR}/"

# Assets (excluding .DS_Store)
echo "Copying assets..."
mkdir -p "${STAGE_DIR}/Assets"
find Assets -type f \( -name "*.tga" -o -name "*.blp" \) -exec cp {} "${STAGE_DIR}/Assets/" \;

# Libraries
if [ -d "Libs" ]; then
    echo "Copying libraries..."
    cp -r Libs "${STAGE_DIR}/"
fi

# Clean up .DS_Store from all copied directories
find "${STAGE_DIR}" -name ".DS_Store" -delete

# Create ZIP
echo "Creating ZIP package..."
cd "${BUILD_DIR}"
zip -r "${ZIP_NAME}" "${PROJECT_NAME}/" -q
cd ..

# Clean up staging folder
echo "Cleaning up..."
rm -rf "${STAGE_DIR}"

# Results
echo ""
echo "$SEPARATOR"
echo "Build complete!"
echo "$SEPARATOR"
echo "Package: ${ZIP_PATH}"
echo "Size: $(du -h "${ZIP_PATH}" | cut -f1)"
echo ""
echo "Contents:"
unzip -l "${ZIP_PATH}" | head -30
echo ""
echo "Ready to upload to CurseForge!"
echo "$SEPARATOR"
