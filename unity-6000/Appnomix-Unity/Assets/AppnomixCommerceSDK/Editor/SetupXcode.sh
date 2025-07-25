#!/bin/bash

### TODO: This value should correspond to the app group name used in the AppnomixCommerceSDK.start call
APP_GROUPS_NAME=group.YOUR_APP_GROUPS_NAME

# Check if APP_GROUPS_NAME is defined and not empty
if [ -z "$APP_GROUPS_NAME" ]; then
  echo "Fatal error: App Group is not defined. Ensure that APP_GROUPS_NAME is set to a valid value." >&2
  exit 1
fi
echo "App Group is set to: $APP_GROUPS_NAME"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_PATH="$1"
XC_TEMPLATE_NAME="Appnomix.Safari.Extension.xctemplate"
XC_FRAMEWORK_NAME="AppnomixCommerce.xcframework"

XC_VERSION=1.7.3

TEMPLATE_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary/releases/download/$XC_VERSION/$XC_TEMPLATE_NAME.zip"
SWIFT_PACKAGE_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary"

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

APP_EXTENSION_NAME="$TARGET_NAME Extension"
APP_EXTENSION_DIR_PATH="$PROJECT_PATH/$APP_EXTENSION_NAME"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Create Appnomix Safari Extension template folder

USER_HOME=$(eval echo ~)
TEMPLATES_DIR="$USER_HOME/Library/Developer/Xcode/Templates"
TEMPLATE_PATH="$TEMPLATES_DIR/$XC_TEMPLATE_NAME"

mkdir -p "$TEMPLATES_DIR"

[ -d "$TEMPLATES_DIR/$XC_TEMPLATE_NAME" ] && rm -rf "$TEMPLATE_PATH"

echo "Downloading Safari Extension from $TEMPLATE_URL"
curl -s -L -o "output.zip" $TEMPLATE_URL

if ! unzip "output.zip"; then
    echo "Error: Failed to unzip $XC_TEMPLATE_NAME.zip"
    exit 1
fi
echo "Safari Extension downloaded and unzipped successfully."

# replace App Groups for Appnomix Extension.entitlements and SafariWebExtensionHandler.swift
echo "[AppGroups] Set $APP_GROUPS_NAME as App Groups name"

find "$XC_TEMPLATE_NAME" \( -name 'SafariWebExtensionHandler.swift' -o -name 'Appnomix Extension.entitlements' \) -type f | while read -r file; do
    echo "[AppGroups] Processing file: $file"
    sed -i '' -e "s/group\.YOUR_APP_GROUPS_NAME/$APP_GROUPS_NAME/g" "$file"
done

mv "$XC_TEMPLATE_NAME" "$TEMPLATES_DIR/"
mkdir -p "$APP_EXTENSION_DIR_PATH"
cp "$TEMPLATE_PATH/Appnomix Extension.entitlements" "$APP_EXTENSION_DIR_PATH/"
cp "$TEMPLATE_PATH"/*.swift "$APP_EXTENSION_DIR_PATH/"
cp "$TEMPLATE_PATH/Info.plist" "$APP_EXTENSION_DIR_PATH/Info.plist"
cp -r "$TEMPLATE_PATH/Resources" "$APP_EXTENSION_DIR_PATH/"

cd "$PROJECT_PATH"

# Check if exactly one .xcodeproj file was found
if [ -z "$XCODEPROJ_FILE" ]; then
    echo "Error: No .xcodeproj file found in the current directory."
    exit 1
elif [ $(echo "$XCODEPROJ_FILE" | wc -l) -gt 1 ]; then
    echo "Error: Multiple .xcodeproj files found in the current directory."
    exit 1
fi

echo "XCODEPROJ_FILE: $XCODEPROJ_FILE"
echo "template: $TEMPLATE_PATH"

add_new_target_with_template() {
    # Path to your .xcodeproj file
    project_path="$1"
    
    # Name of the existing target to duplicate (template)
    template_target_name="$2"
    
    # path of the new app extension dir
    app_extension_dir_path="$3"
    
    # New target name with " Extension" appended
    new_target_name="$template_target_name Extension"
    
    # Open the Xcode project
    xcodebuild -project "$project_path" -list > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Xcode project at $project_path is invalid or cannot be opened."
        exit 1
    fi
    
    # Use xcodeproj gem to modify the project
    ruby -e "$(cat <<EOF
require 'xcodeproj'
require 'plist'

target_name = '$template_target_name'
extension_name = '$template_target_name Extension'

# Path to your .xcodeproj file
project_path = '$project_path'

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Check if the new target already exists
existing_target = project.targets.find { |target| target.name == "#{extension_name}" }
if existing_target
  puts "Target '#{extension_name}' already exists. Skipping creation."
  exit 0
end

# Find the template target to use as a reference
template_target = project.targets.find { |target| target.name == "#{target_name}" }
if template_target.nil?
  puts 'Error: Template target "#{target_name}" not found in "#{project_path}"'
  exit 1
end

# Get the path to the .xctemplate directory
template_dir = File.expand_path('$app_extension_dir_path')
if !Dir.exist?(template_dir)
  puts 'Error: Template directory "#{template_dir}" not found.'
  exit 1
end


# versioning - begin
current_project_version = '$XC_VERSION' # CFBundleVersion 
marketing_version = '$XC_VERSION' # CFBundleShortVersionString

info_plist_file_setting = template_target.resolved_build_setting('INFOPLIST_FILE')
info_plist_file = if info_plist_file_setting.is_a?(Hash)
  info_plist_file_setting['Release'] || info_plist_file_setting.values.first
else
  info_plist_file_setting
end

# Read and parse the Info.plist file
if info_plist_file.nil? || !File.exist?(info_plist_file)
  puts 'Error: Info.plist file not found for the target #{target_name}'
else 
  # Parse the plist and fetch version
  plist = Plist.parse_xml(info_plist_file)
  current_project_version = plist['CFBundleVersion']
  marketing_version = plist['CFBundleShortVersionString']
end

puts "[versioning] Found CFBundleVersion: #{current_project_version}, CFBundleShortVersionString: #{marketing_version}"
# versioning - end


# Duplicate the template target to create a new target
platform_name = template_target.platform_name.to_s.empty? ? :ios : template_target.platform_name.to_sym


new_target = project.new_target(:app_extension, extension_name, platform_name, template_target.deployment_target)

# Add the extension target as a dependency to the Unity-iPhone target
template_target.add_dependency(new_target)

# Print all group names for debugging purposes
puts "Available groups in the project:"
project.groups.each do |group|
  puts group.name
end

# Get the project main group
template_group = project.main_group.find_subpath(extension_name, true)
template_group.set_source_tree('<group>')

# Copy Bundle Resources
path_resources = File.join(template_dir, 'Resources')
Dir.foreach(path_resources) do |entry|
  next if entry == '.' || entry == '..' || entry == '.DS_Store' || entry == 'Info.plist' || entry == 'Appnomix Extension.entitlements'
  path = File.join(path_resources, entry)
  assets_ref = template_group.new_reference(path)
  new_target.add_resources([assets_ref])
  puts "Added file #{entry} as bundle resource to #{template_group.name}"
end

# Add swift files to Compile Sources
Dir.foreach(template_dir) do |entry|
  next if entry == '.' || entry == '..' || entry == '.DS_Store' || entry == 'Info.plist' || entry == 'Appnomix Extension.entitlements'
  if entry.end_with?('.swift')
    path = File.join(template_dir, entry)
    file_ref = template_group.new_file(path)
    new_target.add_file_references([file_ref])
    puts "Added file #{entry} as compile source to #{template_group.name}"
  end
end

development_team = template_target.build_settings('Debug')['DEVELOPMENT_TEAM'] || template_target.build_settings('Release')['DEVELOPMENT_TEAM']

new_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['PRODUCT_NAME'] = extension_name
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "$BUNDLE_ID.appnomixextension"
  config.build_settings['CURRENT_PROJECT_VERSION'] = current_project_version
  config.build_settings['MARKETING_VERSION'] = marketing_version
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['INFOPLIST_FILE'] = "$APP_EXTENSION_NAME/Info.plist"
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = extension_name
  config.build_settings['OTHER_LDFLAGS'] = [
    '-framework',
    'SafariServices'
  ]
end

new_target.product_type = 'com.apple.product-type.app-extension'

# Save the changes to the Xcode project file
project.save

puts "Successfully added new target '#{extension_name}' based on template '#{target_name}' to '#{project_path}'"
EOF
    )"
}

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

add_new_target_with_template "$XCODEPROJ_FILE" "$TARGET_NAME" "$APP_EXTENSION_DIR_PATH"
list_all_targets "$XCODEPROJ_FILE"

# Example Usage:
# link_swift_package_binary_to_target "Demo SwiftUI.xcodeproj" "https://github.com/NomixGroup/ios_commerce_sdk_binary" "AppnomixCommerce" "Demo SwiftUI" "1.4"
link_swift_package_binary_to_target() {
    local XCODEPROJ_PATH="$1"
    local PACKAGE_URL="$2"
    local PRODUCT_NAME="$3"
    local TARGET_NAME="$4"
    local EXACT_VERSION="$5"

    # Ensure the version format is correct (e.g., "1.4" -> "1.4.0")
    if [[ "$EXACT_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        EXACT_VERSION="${EXACT_VERSION}.0"
    fi

    echo "Linking remote Swift package at '$PACKAGE_URL' ($PRODUCT_NAME) ($EXACT_VERSION) to target '$TARGET_NAME' in project '$XCODEPROJ_PATH'..."

    ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
package_url = "$PACKAGE_URL"
product_name = "$PRODUCT_NAME"
target_name = "$TARGET_NAME"
exact_version = "$EXACT_VERSION"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Target '#{target_name}' not found!"
  exit 1
end

# Ensure package references exist
project.root_object.attributes["PackageReferences"] ||= []

# Find or create the package reference
package_reference = project.root_object.package_references.find { |pkg| pkg.repositoryURL == package_url }
unless package_reference
  package_reference = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package_reference.repositoryURL = package_url
  package_reference.requirement = { "kind" => "exactVersion", "version" => exact_version }

  project.root_object.package_references << package_reference
  puts "Added new package reference for '#{package_url}'"
else
  package_reference.requirement = { "kind" => "exactVersion", "version" => exact_version }
  puts "Package reference for '#{package_url}' already exists"
end

# Check for existing product dependency
product_dependencies = project.objects.select { |obj| obj.isa == "XCSwiftPackageProductDependency" }
product_dependency = product_dependencies.find { |obj| obj.product_name == product_name }

unless product_dependency
  product_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dependency.product_name = product_name
  product_dependency.package = package_reference
  project.objects << product_dependency
  puts "Created XCSwiftPackageProductDependency for '#{product_name}'"
end

# Add to Link Binary With Libraries using productRef
frameworks_build_phase = target.frameworks_build_phase || target.new_frameworks_build_phase

# Check if the product is already in the frameworks build phase
build_file = frameworks_build_phase.files.find { |bf| bf.respond_to?(:product_ref) && bf.product_ref == product_dependency }
unless build_file
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dependency  # Use product_ref instead of file_ref
  frameworks_build_phase.files << build_file
  puts "Added '#{product_name}' to Link Binary With Libraries (using productRef)"
else
  puts "'#{product_name}' already exists in Link Binary With Libraries"
end

# Save changes
project.save
puts "Successfully processed remote Swift package '#{product_name}' for target '#{target_name}'"
puts ""
EOF
}

link_swift_package_binary_to_target "$XCODEPROJ_FILE" "$SWIFT_PACKAGE_URL" "AppnomixCommerce" "UnityFramework" "$XC_VERSION"
link_swift_package_binary_to_target "$XCODEPROJ_FILE" "$SWIFT_PACKAGE_URL" "AppnomixCommerce" "$APP_EXTENSION_NAME" "$XC_VERSION"
link_swift_package_binary_to_target "$XCODEPROJ_FILE" "$SWIFT_PACKAGE_URL" "AppnomixCommerce" "$TARGET_NAME" "$XC_VERSION"

add_swift_to_UnityFramework() {
    project_path="$1"
    target_name="$2"
    swift_source_path="$3"
    swift_dest_path="$4"
    swift_file_name="$5"

    cp "$swift_source_path/$swift_file_name" "$swift_dest_path"

    ruby - <<EOF
require 'xcodeproj'

project_path = '$project_path' # path to .xcodeproj file
target_name = '$target_name' # target name
swift_dest_path = '$swift_dest_path'
swift_file_name = '$swift_file_name'

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

  target = project.targets.find { |t| t.name == target_name }
  if target
    target_group = project.main_group.find_subpath(target_name, true)
    target_group.set_source_tree('<group>')

    path = File.join(swift_dest_path, swift_file_name)

    # Check if the file already exists in the project
    file_ref = target_group.files.find { |f| f.path == swift_file_name }

    if file_ref
      puts "File #{swift_file_name} is already added to target #{target_name}"
    else
      file_ref = target_group.new_file(path)
      target.add_file_references([file_ref])
      puts "File #{swift_file_name} added to target #{target_name}"
    end
    
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '5'
    end
  else
    puts "Target not found: #{target_name}"
  end

# Save the project file
project.save

EOF
}

# commenting out because Unity automatically add the swift file into the Libraries/AppnomixCommerceSDK folder
# add Appnomix.swift file to UnityFramework to avoid lib compatibility issues
#add_swift_to_UnityFramework "$PROJECT_PATH/$XCODEPROJ_FILE" "UnityFramework" "$SCRIPT_DIR/../" "$PROJECT_PATH/UnityFramework" "Appnomix.swift"

add_resource_file_to_target() {

  local XCODEPROJ_PATH="$1"
  local TARGET_NAME="$2"
  local FILE_PATH="$3"

  # Ensure the file exists
  if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' not found."
    return 1
  fi

  echo "Adding file: $FILE_PATH to target: $TARGET_NAME under the main group"

  ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
target_name = "$TARGET_NAME"
file_path = "$FILE_PATH"
file_name = File.basename(file_path)

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Error: Target '#{target_name}' not found."
  exit 1
end

# Use the main project group
main_group = project.main_group

# Check if the file is already in the project
file_ref = main_group.find_file_by_path(file_name) || main_group.new_reference(file_path)

# Ensure the file is added to the target's source build phase
unless target.resources_build_phase.files_references.include?(file_ref)
  target.add_resources([file_ref])
  puts "Added file: '#{file_name}' to the main group under target: '#{target_name}'"
else
  puts "File '#{file_name}' already exists in the target."
end

# Save changes
project.save
puts "Xcode project updated successfully."

EOF
}

# Copy customization file for colors
JSON_FILE_SOURCE="$SCRIPT_DIR/../Resources/AppnomixCustomizationPoints.json"
if [ -f "$JSON_FILE_SOURCE" ]; then
  cp "$JSON_FILE_SOURCE" "$PROJECT_PATH"
  add_resource_file_to_target "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$PROJECT_PATH/AppnomixCustomizationPoints.json"
else
  echo "AppnomixCustomizationPoints.json file not found. Skipping customization."
fi

# add NSUserTrackingUsageDescription to Info.plist
add_privacy_permissions() {
    ruby <<EOF
require 'xcodeproj'
require 'plist'

project_path = '$1' # project path

  # Find the Info.plist file in the project directory
  info_plist_path = File.join(project_path, '..', 'Info.plist')

  # Modify the Info.plist file
  if File.exist?(info_plist_path)
    plist = Plist.parse_xml(info_plist_path)

    puts "Adding permissions to #{info_plist_path}"
    
    # NSUserTrackingUsageDescription
    if plist.key?('NSUserTrackingUsageDescription')
      puts "NSUserTrackingUsageDescription is already defined: [#{plist['NSUserTrackingUsageDescription']}]"
    else
      plist['NSUserTrackingUsageDescription'] = "We will use your data to provide a better and personalized ad experience."
      File.write(info_plist_path, plist.to_plist)
      puts "Added NSUserTrackingUsageDescription to #{info_plist_path}"
    end
  else
    puts "Error: Info.plist file not found at #{info_plist_path}"
    exit 1
  end

EOF
}

add_privacy_permissions "$PROJECT_PATH/$XCODEPROJ_FILE"

# app groups
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

cd "$PROJECT_PATH"

ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$TARGET_NAME/$TARGET_NAME.entitlements" "$APP_GROUPS_NAME"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$APP_GROUPS_NAME"

add_copy_files_build_phase() {
    ruby <<EOF
  require 'xcodeproj'

  project_path = '$1' # 1 = project file
  target_name = '$2'
  build_phase_name = '$3'
  dst_subfolder_spec ='$4'
  dst_path = '$5'
  files = $6

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

# add xcprivacy
privacy_info_content=$(cat <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>1C8F.1</string>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
XML
)
echo "$privacy_info_content" > "$PROJECT_PATH/PrivacyInfo.xcprivacy"

update_extension_name() {
    ruby <<EOF
require 'json'
require 'plist'

  project_path = '$1' # project path 
  json_path = '$2' # messages.json path
  new_extension_name = '$3'

  # Find the Info.plist file in the project directory
  info_plist_path = File.join(project_path, 'Info.plist')

  puts "Getting extension name from #{info_plist_path}"

  # Get bundle display name from the Info.plist file
  if File.exist?(info_plist_path)
    plist = Plist.parse_xml(info_plist_path)
    
    if plist.key?('CFBundleDisplayName')
      new_extension_name = plist['CFBundleDisplayName']
      puts "New extension name found #{new_extension_name}"
    else
      puts "CFBundleDisplayName not found in #{info_plist_path}"
    end
  else
    puts "File not found #{info_plist_path}"
  end

  puts "Opening JSON file #{json_path}..."

  # Read the JSON file
  json_content = File.read(json_path)
  
  # Parse the JSON
  data = JSON.parse(json_content)
  
  # Update the extension_name.message value
  if data['extension_name'] && data['extension_name']['message']
    data['extension_name']['message'] = new_extension_name
    puts "Updating extension name to #{new_extension_name}"
  else
    puts "extension_name or extension_name.message not found in JSON"
    return
  end

  # Convert the updated hash back to JSON
  updated_json_content = JSON.pretty_generate(data)

  # Write the updated JSON back to the file
  File.open(json_path, 'w') do |file|
    file.write(updated_json_content)
  end

  puts "Successfully updated extension_name.message to '#{new_extension_name}'"

EOF
}

update_extension_name "$PROJECT_PATH" "$APP_EXTENSION_DIR_PATH/Resources/_locales/en/messages.json" "Appnomix Extension"

copy_logo_image() {
    local input_image_path="$1"
    local output_image_base_path="$2"
    local output_image_base_name="$3"
    local sizes=($4)

    echo "Replacing branded logo..."
    for size in "${sizes[@]}"; do
        output_image_path="${output_image_base_path}/${output_image_base_name}-${size}.png"
        sips -z "$size" "$size" "$input_image_path" --out "$output_image_path" > /dev/null 2>&1
        echo "Creating logo ${output_image_path}"
    done
}

copy_logo_image "$SCRIPT_DIR/../Resources/logo.png" "$APP_EXTENSION_DIR_PATH/Resources/images" "icon" "48 64 96 128 256 512"
copy_logo_image "$SCRIPT_DIR/../Resources/logo.png" "$APP_EXTENSION_DIR_PATH/Resources/images" "toolbar-icon" "16 19 32 38 48 72"

create_xcprivacy_ref() {
    ruby - <<EOF
require 'xcodeproj'

# Path to your .xcodeproj file
project_path = '$project_path'

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find or create the group where PrivacyInfo.xcprivacy will reside
privacy_group = project.main_group

# Create a new file reference for PrivacyInfo.xcprivacy
file_reference = privacy_group.new_file('PrivacyInfo.xcprivacy')

# Set the file's content
file_reference.set_explicit_file_type('text.plist.xml')
file_reference.set_source_tree('<group>')

# Add the file reference to each target
project.targets.each do |target|
  target.add_file_references([file_reference])
  puts "Added PrivacyInfo.xcprivacy to '#{target.name}'"
end

# Save the changes to the project
project.save

puts "Successfully added PrivacyInfo.xcprivacy to all targets in '#{project_path}'"
EOF
}

# TODO: merge info with the existing PrivacyInfo file 
# create_xcprivacy_ref "$PROJECT_PATH/$XCODEPROJ_FILE" 

rm -rf "$TEMP_DIR"

echo "done 😀"
