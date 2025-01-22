#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Update this path to your Unity executable
UNITY_PATH="/Applications/Unity/Hub/Editor/2022.3.54f1/Unity.app/Contents/MacOS/Unity"

PROJECT_PATH="$SCRIPT_DIR/Unity"  # path to Unity project
PACKAGE_NAME="unity-1.3.unitypackage"  # name of the package
EXPORT_PATH="$SCRIPT_DIR/build"     # Set the directory to export the package

# Asset folders (one per line)
ASSETS_TO_EXPORT="Assets/AppnomixCommerceSDK Assets/Plugins/Android"

# Create export directory
mkdir -p "$EXPORT_PATH"

# Export package
echo "Exporting Unity package..."
"$UNITY_PATH" -batchmode -nographics -quit -projectPath "$PROJECT_PATH" -exportPackage $ASSETS_TO_EXPORT "$EXPORT_PATH/$PACKAGE_NAME"

# Check if the export was successful
if [ $? -eq 0 ]; then
    echo "Unity package exported successfully to $EXPORT_PATH/$PACKAGE_NAME"
else
    echo "Failed to export Unity package."
    exit 1
fi
