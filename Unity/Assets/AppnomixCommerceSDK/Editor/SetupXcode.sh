#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROJECT_PATH="$1"
XC_TEMPLATE_NAME="Appnomix.Safari.Extension.xctemplate"
XC_FRAMEWORK_NAME="AppnomixCommerce.xcframework"

XC_VERSION=0.2.48

TEMPLATE_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary/releases/download/$XC_VERSION/$XC_TEMPLATE_NAME.zip"
BINARY_SDK_URL="https://github.com/NomixGroup/ios_commerce_sdk_binary/releases/download/$XC_VERSION/$XC_FRAMEWORK_NAME.zip"
TEMPLATE_IDENTIFIER="app.appnomix.dt.unit.iosSafariExtension"

cd "$PROJECT_PATH"

# Find the .xcodeproj file in the current directory
XCODEPROJ_FILE=$(find . -name "*.xcodeproj" -maxdepth 1 -type d)
BUNDLE_ID=$(xcodebuild -showBuildSettings | awk '/PRODUCT_BUNDLE_IDENTIFIER/ { print $3 }')
TARGET_NAME=$(basename "$XCODEPROJ_FILE" .xcodeproj)

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

# PART 1: create new "MyProject Extension" from template

echo "Downloading Safari Extension from $TEMPLATE_URL"
curl -s -L -o "output.zip" $TEMPLATE_URL
unzip "output.zip"

# replace App Groups for Appnomix Extension.entitlements and SafariWebExtensionHandler.swift
GROUP_NAME="group\.$BUNDLE_ID"

find "$XC_TEMPLATE_NAME" -type f -exec grep -Il '' {} + | while read -r file; do
    echo "Processing file: $file"
    sed -i '' -e "s/group\.com\.saversleague\.coupons/$GROUP_NAME/g" "$file"
done

# TODO: replace extension name
# find "$XC_TEMPLATE_NAME" -type f -exec grep -Il '' {} + | while read -r file; do
#     echo "Processing file: $file"
#     sed -i '' -e "s/group\.com\.saversleague\.coupons/$TARGET_NAME/g" "$file"
# done

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
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15'
  config.build_settings['PRODUCT_NAME'] = extension_name
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "$BUNDLE_ID.appnomix-extension"
  config.build_settings['CURRENT_PROJECT_VERSION'] = '$XC_VERSION'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['INFOPLIST_FILE'] = "$APP_EXTENSION_NAME/Info.plist"
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

# PART 2: add the xcframework
cd "$TEMP_DIR"
echo "Downloading XCFramework from $BINARY_SDK_URL"
curl -s -L -o xcframework.zip $BINARY_SDK_URL
unzip xcframework.zip
mv "$XC_FRAMEWORK_NAME" "$PROJECT_PATH/"

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

framework_ref = project.frameworks_group.find_file_by_path(xcframework_name) || project.frameworks_group.new_reference(xcframework_name)

target_names.each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  if target
    unless target.frameworks_build_phase.files_references.include?(framework_ref)
      target.frameworks_build_phase.add_file_reference(framework_ref)
      puts "Added framework reference to target: #{target_name}"
    else
      puts "Framework reference already exists in target: #{target_name}"
    end
  else
    puts "Target not found: #{target_name}"
  end
end

# Save the project file
project.save

EOF
}

add_framework_reference "$PROJECT_PATH/$XCODEPROJ_FILE" "$XC_FRAMEWORK_NAME" "$APP_EXTENSION_NAME" "UnityFramework"


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

# PART 3: add NSUserTrackingUsageDescription, NSLocationAlwaysUsageDescription, NSLocationWhenInUseUsageDescription to Info.plist
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

    # NSLocationWhenInUseUsageDescription
    if plist.key?('NSLocationWhenInUseUsageDescription')
      puts "NSLocationWhenInUseUsageDescription is already defined: [#{plist['NSLocationWhenInUseUsageDescription']}]"
    else
      plist['NSLocationWhenInUseUsageDescription'] = "Find exclusive deals and discounts in your area"
      File.write(info_plist_path, plist.to_plist)
      puts "Added NSLocationWhenInUseUsageDescription to #{info_plist_path}"
    end

    # NSLocationAlwaysUsageDescription
    if plist.key?('NSLocationAlwaysUsageDescription')
      puts "NSLocationAlwaysUsageDescription is already defined: [#{plist['NSLocationAlwaysUsageDescription']}]"
    else
      plist['NSLocationAlwaysUsageDescription'] = "Find exclusive deals and discounts in your area"
      File.write(info_plist_path, plist.to_plist)
      puts "Added NSLocationAlwaysUsageDescription to #{info_plist_path}"
    end
  else
    puts "Error: Info.plist file not found at #{info_plist_path}"
    exit 1
  end

EOF
}

add_privacy_permissions "$PROJECT_PATH/$XCODEPROJ_FILE"

# PART 4: app groups
ensure_app_groups_exists() {
    ruby <<EOF
require 'xcodeproj'
require 'plist'

project_path = '$1' # 1 = project file
target_name = '$2'
entitlements_file_path = '$3' # entitlements path
bundle_id = '$4'

puts "Entitlements: #{entitlements_file_path}; present: #{File.exist?(entitlements_file_path)}"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Target #{target_name} not found"
  exit 1
end

# Define the app group
app_group = "group.#{bundle_id}"

# Initialize entitlements hash
entitlements = {}

# Load entitlements from file if it exists
if File.exist?(entitlements_file_path)
  begin
    entitlements = Plist.parse_xml(entitlements_file_path)
    entitlements ||= {}  # Ensure entitlements is not nil
  rescue StandardError => e
    puts "Error loading entitlements file: #{e.message}"
  end
else
  puts "Entitlements file not found at #{entitlements_file_path}"
end

# Ensure 'com.apple.security.application-groups' is initialized as an array
entitlements['com.apple.security.application-groups'] ||= []

puts "entitlements: #{entitlements}"

# Check if app_group already exists
if entitlements['com.apple.security.application-groups'].include?(app_group)
  puts "App group #{app_group} already exists."
else
  # Add app_group to entitlements
  entitlements['com.apple.security.application-groups'] << app_group

  # Write updated entitlements to file
  begin
    File.open(entitlements_file_path, 'w') do |file|
      file.write(entitlements.to_plist)
    end
  rescue StandardError => e
    puts "Error writing entitlements file: #{e.message}"
    exit 1
  end
end

# Ensure the entitlements setting is in the build settings
target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_file_path
end

# Save the project
project.save

puts "App group #{app_group} added to target #{target_name} successfully."

EOF
}

cd "$PROJECT_PATH"

echo "bundle id: $BUNDLE_ID"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$TARGET_NAME" "$PROJECT_PATH/$TARGET_NAME/$TARGET_NAME.entitlements" "$BUNDLE_ID"
ensure_app_groups_exists "$PROJECT_PATH/$XCODEPROJ_FILE" "$APP_EXTENSION_NAME" "$PROJECT_PATH/$APP_EXTENSION_NAME/Appnomix Extension.entitlements" "$BUNDLE_ID"


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
  unless copy_files_phase
    copy_files_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    copy_files_phase.name = build_phase_name
    copy_files_phase.dst_subfolder_spec = dst_subfolder_spec
    copy_files_phase.dst_path = dst_path
    puts "Created new build phase '#{build_phase_name}'"
  else
    puts "Build phase '#{build_phase_name}' already exists"
    exit 0
  end

  # Add files to the Copy Files build phase
  files.each do |file_path|
    file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_file(file_path)
    file_ref.source_tree = 'BUILT_PRODUCTS_DIR'
    copy_files_phase.add_file_reference(file_ref)
    puts "Added file #{file_path} to Copy Files build phase."
  end

  # Add it to the first available position to avoid conflict with Firebase Run Script
  target.build_phases.unshift(copy_files_phase)

  # Save the project
  project.save
  puts "Successfully added Copy Files build phase #{build_phase_name} to target #{target_name}."

EOF
}

add_copy_files_build_phase "$XCODEPROJ_FILE" "$TARGET_NAME" "Embed Foundation Extensions" '13' "" "['$APP_EXTENSION_NAME.appex']"

# PART 5: add xcprivacy
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

  puts "#{info_plist_path}"

  # Get bundle display name from the Info.plist file
  if File.exist?(info_plist_path)
    plist = Plist.parse_xml(info_plist_path)
    
    # Check if NSUserTrackingUsageDescription is already defined
    if plist.key?('CFBundleDisplayName')
      new_extension_name = plist['CFBundleDisplayName']
      puts "CFBundleDisplayName is already defined in #{info_plist_path}"
    end
  end

  puts "Opening JSON file #{json_path}..."

  # Read the JSON file
  json_content = File.read(json_path)
  
  # Parse the JSON
  data = JSON.parse(json_content)
  
  # Update the extension_name.message value
  if data['extension_name'] && data['extension_name']['message']
    data['extension_name']['message'] = new_extension_name
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
