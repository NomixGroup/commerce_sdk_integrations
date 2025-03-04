#!/bin/bash

# Load functions
source "$(dirname "$0")/SetupXCode/xcode_targets.sh"
source "$(dirname "$0")/SetupXCode/xcode_resources.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_to_target.sh"
source "$(dirname "$0")/SetupXCode/xcode_files_build_phase.sh"
source "$(dirname "$0")/SetupXCode/xcode_framework.sh"

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
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/Appnomix Frameworks/"/* "$PROJECT_PATH"
mkdir -p "$PROJECT_PATH/Appnomix.xcassets"
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/Appnomix.xcassets/"/* "$PROJECT_PATH/Appnomix.xcassets"
cp -R "$TEMP_DIR/Appnomix Keyboard Resources/MainApp/"/* "$PROJECT_PATH/MainApp"

cd "$PROJECT_PATH"

# cleanup
rm -rf "$TEMP_DIR"


add_custom_keyboard_extension_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/$APP_EXTENSION_NAME/"

add_xcassets_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "Appnomix.xcassets"

add_files_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "Unity-iPhone" "MainApp" "$PROJECT_PATH/MainApp"

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


add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"

add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "AppnomixSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardAI.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardSDK.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"
add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "KeyboardView.xcframework" "$APP_EXTENSION_NAME" "$TARGET_NAME"

ensure_app_groups_exists() {
    ruby <<EOF
require 'xcodeproj'
require 'plist'

project_path = '$1' # project file
target_name = '$2' # target name
entitlements_file_path = '$3' # entitlements path
app_groups_name = '$4' # app group name to add

puts ""
puts "[AppGroups] Start searching CODE_SIGN_ENTITLEMENTS for target: #{target_name}"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Target #{target_name} not found"
  exit 1
end

current_entitlements_file_path = ''

# Check if CODE_SIGN_ENTITLEMENTS is already set in the build settings
target.build_configurations.each do |config|
  current_entitlements_file_path = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  puts "[AppGroups] Searching in configuration: #{config.name}"

  if current_entitlements_file_path && !current_entitlements_file_path.empty?
    puts "[AppGroups] Found entitlements file: #{current_entitlements_file_path} in configuration: #{config.name}"
    break
  end
end

if current_entitlements_file_path.nil? || current_entitlements_file_path.empty?
  current_entitlements_file_path = entitlements_file_path
  puts "[AppGroups] CODE_SIGN_ENTITLEMENTS not set. Using default path: #{current_entitlements_file_path}"
else
  
end

# Initialize entitlements hash
entitlements = {}

# Load entitlements from file if it exists
if File.exist?(current_entitlements_file_path)
  begin
    entitlements = Plist.parse_xml(current_entitlements_file_path)
    entitlements ||= {}  # Ensure entitlements is not nil
  rescue StandardError => e
    puts "Error loading entitlements file: #{e.message}"
    exit 1
  end
else
  puts "[AppGroups] Entitlements file not found at #{current_entitlements_file_path}, creating a new one."
  current_entitlements_file_path = entitlements_file_path
end

# Ensure 'com.apple.security.application-groups' is initialized as an array
entitlements['com.apple.security.application-groups'] ||= []

puts "[AppGroups] Current entitlements: #{entitlements}"

# Check if app_groups_name already exists in entitlements
if entitlements['com.apple.security.application-groups'].include?(app_groups_name)
  puts "[AppGroups] App group #{app_groups_name} already exists in entitlements."
else
  # Add app_groups_name to the array if it does not exist
  entitlements['com.apple.security.application-groups'] << app_groups_name
  puts "[AppGroups] App group #{app_groups_name} added to entitlements."

  # Write the updated entitlements back to the file
  begin
    File.open(current_entitlements_file_path, 'w') do |file|
      file.write(entitlements.to_plist)
    end
    puts "[AppGroups] Entitlements successfully updated."
  rescue StandardError => e
    puts "Error writing entitlements file: #{e.message}"
    exit 1
  end
end

puts "[AppGroups] Updated entitlements: #{entitlements}"

# Ensure the entitlements file is set in the build settings if not already set
target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = current_entitlements_file_path
  puts "[AppGroups] CODE_SIGN_ENTITLEMENTS set to: #{current_entitlements_file_path} for configuration: #{config.name}"
end

# Save the project
project.save

puts "[AppGroups] App group #{app_groups_name} successfully ensured for target #{target_name} to #{current_entitlements_file_path}."
puts ""

EOF
}

# ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
# ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

echo "done 😀"
