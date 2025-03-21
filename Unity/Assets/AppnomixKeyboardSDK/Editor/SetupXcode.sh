#!/bin/bash

# Load functions
source "$(dirname "$0")/SetupXCode/xcode_targets.sh"
source "$(dirname "$0")/SetupXCode/xcode_resources.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_to_target.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_build_phase.sh"
source "$(dirname "$0")/SetupXCode/xcode_framework.sh"
source "$(dirname "$0")/SetupXCode/xcode_app_groups.sh"
source "$(dirname "$0")/SetupXCode/xcode_update_main.sh"
source "$(dirname "$0")/SetupXCode/xcode_get_bundle_name.sh"
source "$(dirname "$0")/SetupXCode/xcode_get_project_versions.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_to_compile.sh"
source "$(dirname "$0")/SetupXCode/xcode_add_permissions.sh"
source "$(dirname "$0")/SetupXCode/xcode_update_content_view.sh"
source "$(dirname "$0")/SetupXCode/xcode_update_keyboard_content.sh"


### TODO: These values should be set by the client
APP_GROUPS_NAME=group.app.appnomix.demo-unity
YOUR_CLIENT_ID=your-client
YOUR_AUTH_TOKEN=your-auth-token
YOUR_APP_SCHEME=your-app-scheme

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
BUNDLE_ID=$(xcodebuild -showBuildSettings | grep -w PRODUCT_BUNDLE_IDENTIFIER | awk '{ print $3 }')
TARGET_NAME=$(basename "$XCODEPROJ_FILE" .xcodeproj)
echo "Found TARGET_NAME=$TARGET_NAME"
echo "Found BUNDLE_ID=$BUNDLE_ID"

BUNDLE_NAME=$(get_bundle_name "$PROJECT_PATH")
echo "Found BUNDLE_NAME=$BUNDLE_NAME"

APP_EXTENSION_NAME="$BUNDLE_NAME Keyboard"
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

# Get project versions
VERSION_OUTPUT=$(get_project_versions "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME")
# Extract values
export PROJECT_VERSION=$(echo "$VERSION_OUTPUT" | grep "PROJECT_VERSION=" | cut -d '=' -f2)
export MARKETING_VERSION=$(echo "$VERSION_OUTPUT" | grep "MARKETING_VERSION=" | cut -d '=' -f2)

# Add Keyboard target
echo "**Step: add_custom_keyboard_extension_target"
add_custom_keyboard_extension_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/$APP_EXTENSION_NAME/" "$TARGET_NAME" "$PROJECT_VERSION" "$MARKETING_VERSION"
echo "**Step: add_copy_files_build_phase"
add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"

# Add files
echo "**Step: add_xcassets_to_target"
add_xcassets_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "Appnomix.xcassets"
echo "**Step: add_files_to_target"
add_files_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "Unity-iPhone" "MainApp" "$PROJECT_PATH/MainApp"
echo "**Step: add_file_to_compile_sources"
add_file_to_compile_sources "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/MainApp/TypeProSharedSettingsKeys.swift"

# Add frameworks
echo "**Step: add_framework_reference"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "AppnomixSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardAI.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardView.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"

# Configure App Groups
echo "**Step: ensure_app_groups_exists"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

# Update main.mm
echo "**Step: update_main_mm"
update_main_mm "$PROJECT_PATH/MainApp/main.mm" "$BUNDLE_NAME"

# Add NSUserTrackingUsageDescription to Info.plist
echo "**Step: add_privacy_permissions"
add_privacy_permissions "$PROJECT_PATH/$XCODEPROJ_FILE"

# Update ContentView.Swift
echo "**Step: update_content_view_file"
update_content_view_file "$PROJECT_PATH/MainApp/ContentView.swift"

# Update KeyboardContentView.swift
echo "**Step: update_keyboard_content_file"
update_keyboard_content_file "$PROJECT_PATH/$APP_EXTENSION_NAME/KeyboardViewController.swift"

# Function to list all targets in the project using xcodeproj gem
echo "**Step: list_all_targets"
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
