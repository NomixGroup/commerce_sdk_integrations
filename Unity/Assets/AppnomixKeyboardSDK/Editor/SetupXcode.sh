#!/bin/bash

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
cd "$PROJECT_PATH"

# cleanup
rm -rf "$TEMP_DIR"

# Usage: add_custom_keyboard_extension_target <path_to_xcodeproj> <new_target_name>
add_custom_keyboard_extension_target() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: add_custom_keyboard_extension_target <path_to_xcodeproj> <new_target_name> <files_directory>"
    return 1
  fi

  local XCODEPROJ_PATH="$1"
  local NEW_TARGET_NAME="$2"
  local FILES_DIR="$3"

  ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
project = Xcodeproj::Project.open(project_path)

# Check if the new target already exists
existing_target = project.targets.find { |target| target.name == "$NEW_TARGET_NAME" }
if existing_target
  puts "Target '$NEW_TARGET_NAME' already exists. Skipping creation."
  exit 0
end

puts "Files: '$FILES_DIR'"

# Create a new custom keyboard extension target.
new_target = project.new_target('com.apple.product-type.app-extension', "$NEW_TARGET_NAME", 'iOS', '15.0')

# Get DEVELOPMENT_TEAM from the first target's build settings
development_team = nil

project.targets.each do |target|
  target.build_configurations.each do |config|
    if config.build_settings['DEVELOPMENT_TEAM']
      development_team = config.build_settings['DEVELOPMENT_TEAM']
      break
    end
  end
  break if development_team
end

if development_team
  puts "DEVELOPMENT_TEAM: #{development_team}"
else
  puts "DEVELOPMENT_TEAM not found!"
end

# Set the extension point identifier for a custom keyboard extension.
new_target.build_configurations.each do |config|
  config.build_settings['NSExtensionPointIdentifier'] = 'com.apple.keyboard-service'
  config.build_settings['NSExtensionPrincipalClass'] = '\$(PRODUCT_MODULE_NAME).KeyboardViewController'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "$BUNDLE_ID.appnomixkeyboard"
  config.build_settings['DEVELOPMENT_TEAM'] = development_team

  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] = "$NEW_TARGET_NAME/Info.plist"
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = "$NEW_TARGET_NAME"
end

new_target.product_type = 'com.apple.product-type.app-extension'
  
# Get the group for the extension (or create it)
group = project.main_group.find_subpath("$NEW_TARGET_NAME", true)
group.set_source_tree('<group>')

# Add all .swift files from the given directory
Dir.glob('$FILES_DIR/*.{swift}') do |file|  # Fix file filtering
  file_ref = group.new_reference(file)
  new_target.add_file_references([file_ref])
  puts "Added file: #{file}"
end

# Add Media.xcassets folder if it exists
xcassets_path = File.join('$FILES_DIR', 'Media.xcassets')
if File.exist?(xcassets_path)
  xcassets_ref = group.new_reference(xcassets_path)
  new_target.add_resources([xcassets_ref])
  puts "Added asset catalog: #{xcassets_ref.real_path}"
end

# Add the new extension to "Embed Foundation Extensions" phase
# copy_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
# copy_phase.name = "Embed Foundation Extensions"
# copy_phase.dst_subfolder_spec = '13'
# project.targets.first.build_phases << copy_phase

# Create and add the extension proxy
# container_proxy = project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
# container_proxy.container_portal = project.root_object.uuid
# container_proxy.proxy_type = '1'
# container_proxy.remote_global_id_string = new_target.uuid
# container_proxy.remote_info = '$NEW_TARGET_NAME'

# # Add the extension as a build file to the copy phase
# build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
# build_file.file_ref = new_target.product_reference
# copy_phase.files << build_file

project.save
puts "Added new custom keyboard extension target: \#{new_target.name}"
EOF
}
add_custom_keyboard_extension_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/$APP_EXTENSION_NAME/"


add_xcassets_to_target() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: add_xcassets_to_target <path_to_xcodeproj> <target_name> <xcassets_path>"
    return 1
  fi

  local XCODEPROJ_PATH="$1"
  local TARGET_NAME="$2"
  local XCASSETS_PATH="$3"

  ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
target_name = "$TARGET_NAME"
xcassets_path = "$XCASSETS_PATH"
xcassets_group_name = "$XCASSETS_PATH"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Error: Target '#{target_name}' not found."
  exit 1
end

# Ensure the xcassets folder exists
unless File.exist?(xcassets_path)
  puts "Error: xcassets folder '#{xcassets_path}' not found."
  exit 1
end

# Get or create a group specifically for Appnomix.xcassets under the main project structure
xcassets_group = project.main_group.find_subpath(xcassets_group_name, true)
xcassets_group.set_source_tree('<group>')

# Add xcassets reference inside the group
xcassets_ref = xcassets_group.find_file_by_path(File.basename(xcassets_path)) || xcassets_group.new_reference(xcassets_path)

# Add the xcassets reference to the resources build phase
unless target.resources_build_phase.files_references.include?(xcassets_ref)
  target.resources_build_phase.add_file_reference(xcassets_ref)
  puts "Added xcassets folder 'Appnomix.xcassets' to target: #{target_name}"
else
  puts "xcassets folder already exists in target: #{target_name}"
end

# Save changes
project.save
puts "Updated project file successfully."
EOF
}
add_xcassets_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "Appnomix.xcassets"



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


add_copy_files_build_phase() {
    ruby <<EOF
  require 'xcodeproj'

  project_path = '$1' # 1 = project file
  target_name = '$2'
  build_phase_name = '$3'
  dst_subfolder_spec ='$4'
  dst_path = '$5'
  files = $6

  puts "NARCIS"

  # Open the Xcode project
  project = Xcodeproj::Project.open(project_path)

  # Find the target by name
  target = project.targets.find { |t| t.name == target_name }

  if target.nil?
    puts "Error: Target #{target_name} not found in project."
    exit 1
  end

  # Create a new Copy Files build phase if it doesn't exist
  copy_files_phase = target.build_phases.find { |phase| phase.display_name == build_phase_name }
  if copy_files_phase
    puts "Build phase '#{build_phase_name}' already exists"
  else
    copy_files_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    copy_files_phase.name = build_phase_name
    copy_files_phase.dst_subfolder_spec = dst_subfolder_spec
    copy_files_phase.dst_path = dst_path
    puts "Created new build phase '#{build_phase_name}'"

    # Add it to the first available position to avoid conflict with Firebase Run Script
    target.build_phases.unshift(copy_files_phase)
  end

  # Add files to the Copy Files build phase
  files.each do |file_path|
    file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_file(file_path)
    file_ref.source_tree = 'BUILT_PRODUCTS_DIR'
    unless copy_files_phase.files_references.include?(file_ref)
      copy_files_phase.add_file_reference(file_ref)
      puts "Added file #{file_path} to '#{build_phase_name}' build phase."
    else
      puts "File #{file_path} already exists in '#{build_phase_name}' build phase."
    end
  end

  # Save the project
  project.save
  puts "Successfully added Copy Files build phase '#{build_phase_name}' to target #{target_name}."

EOF
}

add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"


add_framework_reference() {
    project_path="$1"
    xcframework_name="$2"
    shift 2
    target_names=("$@")

    # convert the target names array into a Ruby-friendly string
    target_names_ruby=$(printf "'%s', " "${target_names[@]}")
    target_names_ruby="[${target_names_ruby%, }]"

    ruby - <<EOF
require 'xcodeproj'

project_path = '$project_path' # First argument is the path to .xcodeproj file
xcframework_name = '$xcframework_name' # Name of the xcframework file
target_names = $target_names_ruby # Names of the targets

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Ensure 'Frameworks' group exists
frameworks_group = project.groups.find { |group| group.display_name == 'Frameworks' }
frameworks_group ||= project.main_group.new_group('Frameworks')  # Create if missing

# Find or create a framework reference
framework_path = File.join(File.dirname(project_path), xcframework_name)
framework_ref = frameworks_group.find_file_by_path(framework_path) || frameworks_group.new_reference(framework_path)

target_names.each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  if target
    unless target.frameworks_build_phase.files_references.include?(framework_ref)
      file_ref = target.frameworks_build_phase.add_file_reference(framework_ref)
      puts "Added framework reference to target: #{target_name}"
    else
      puts "Framework reference already exists in target: #{target_name}"
    end

    # Embed and sign the framework
    embed_phase = target.copy_files_build_phases.find { |phase| phase.name == 'Embed Frameworks' } ||
                  target.new_copy_files_build_phase('Embed Frameworks')

    embed_phase.symbol_dst_subfolder_spec = :frameworks # Embed frameworks into the Frameworks folder

    unless embed_phase.files_references.include?(framework_ref)
      build_file = embed_phase.add_file_reference(framework_ref)
      build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
      puts "Embedded and set CodeSignOnCopy for framework in target: #{target_name}"
    else
      puts "Framework already embedded and signed in target: #{target_name}"
    end
  else
    puts "Target not found: #{target_name}"
  end
end

# Save the project file
project.save

EOF
}

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

ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

echo "done 😀"
