#!/bin/bash

# Load functions
source "$(dirname "$0")/SetupXCode/xcode_targets.sh"
source "$(dirname "$0")/SetupXCode/xcode_resources.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_to_target.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_build_phase.sh"
source "$(dirname "$0")/SetupXCode/xcode_framework.sh"
source "$(dirname "$0")/SetupXCode/xcode_app_groups.sh"
source "$(dirname "$0")/SetupXCode/xcode_update_main.sh"

### TODO: This value should correspond to the app group name used in the AppnomixKeyboardSDK.start call
APP_GROUPS_NAME=group.app.appnomix.demo-unity

# Check if APP_GROUPS_NAME is defined and not empty
if [ -z "$APP_GROUPS_NAME" ]; then
  echo "Fatal error: App Group is not defined. Ensure that APP_GROUPS_NAME is set to a valid value." >&2
  exit 1
fi
echo "App Group is set to: $APP_GROUPS_NAME"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_PATH="$1"

TEMPLATE_URL="https://github.com/NomixGroup/Appnomix-Unity-Sample/releases/download/test/Appnomix.Keyboard.Resources.zip"

cd "$PROJECT_PATH"

# Display the version of Xcode being used
XCODE_VERSION=$(xcodebuild -version | grep "Xcode")
echo "Using Xcode version: $XCODE_VERSION"

# Find the .xcodeproj file in the current directory
XCODEPROJ_FILE=$(find . -name "*.xcodeproj" -maxdepth 1 -type d)
BUNDLE_ID=$(xcodebuild -showBuildSettings | awk '/PRODUCT_BUNDLE_IDENTIFIER/ { print $3 }')
TARGET_NAME=$(basename "$XCODEPROJ_FILE" .xcodeproj)
echo "Found TARGET_NAME=$TARGET_NAME"
echo "Found BUNDLE_ID=$BUNDLE_ID"

APP_EXTENSION_NAME="$TARGET_NAME Keyboard"
APP_EXTENSION_DIR_PATH="$PROJECT_PATH/$APP_EXTENSION_NAME"

# Check if exactly one .xcodeproj file was found
if [ -z "$XCODEPROJ_FILE" ]; then
    echo "Error: No .xcodeproj file found in the current directory."
    exit 1
elif [ $(echo "$XCODEPROJ_FILE" | wc -l) -gt 1 ]; then
    echo "Error: Multiple .xcodeproj files found in the current directory."
    exit 1
fi
echo "XCODEPROJ_FILE: $XCODEPROJ_FILE"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download resources for Appnomix Keyboard SDK
echo "Downloading Appnomix Keyboard Resources from $TEMPLATE_URL to $TEMP_DIR"
curl -s -L -o "output.zip" "$TEMPLATE_URL"

if ! unzip -q "output.zip"; then
    echo "Error: Failed to unzip file."
    exit 1
fi
echo "Appnomix Keyboard Resources are downloaded and unzipped successfully."

# Copy all files and folders to the project folder
mkdir -p "$APP_EXTENSION_DIR_PATH"
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/Appnomix Keyboard/"/* "$APP_EXTENSION_DIR_PATH"

mkdir -p "$PROJECT_PATH/Frameworks"
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/Appnomix Frameworks/"/* "$PROJECT_PATH/Frameworks"

mkdir -p "$PROJECT_PATH/Appnomix.xcassets"
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/MainApp/Appnomix.xcassets/"/* "$PROJECT_PATH/Appnomix.xcassets"

cp -R "$TEMP_DIR/Appnomix Keyboard Resources/MainApp/"/* "$PROJECT_PATH/MainApp"

cd "$PROJECT_PATH"

# cleanup
rm -rf "$TEMP_DIR"

# Add Keyboard target
add_custom_keyboard_extension_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/$APP_EXTENSION_NAME/"
#add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"

# Add files
add_xcassets_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "Appnomix.xcassets"
add_files_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "Unity-iPhone" "MainApp" "$PROJECT_PATH/MainApp"

# Add frameworks
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "AppnomixSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardAI.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardView.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"

# Configure App Groups
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

# Update main.mm
update_main_mm "$PROJECT_PATH/MainApp/main.mm"


# Function to list all targets in the project using xcodeproj gem
list_all_targets() {
  ruby - <<EOF
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '$1'  # First argument is the path to .xcodeproj file

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Print all targets in the project with their types
puts "Targets in #{project_path}:"
project.targets.each do |target|
  puts "- #{target.name} (#{target.product_type})"
end
EOF
}
list_all_targets "$XCODEPROJ_FILE"

echo "done 😀"
