#!/bin/bash

# Usage: add_custom_keyboard_extension_target <path_to_xcodeproj> <new_target_name>
add_custom_keyboard_extension_target() {
  if [ "$#" -ne 6 ]; then
    echo "Usage: add_custom_keyboard_extension_target <path_to_xcodeproj> <new_target_name> <files_directory> <app_target> <project_version> <marketing_version>"
    return 1
  fi

  local XCODEPROJ_PATH="$1"
  local NEW_TARGET_NAME="$2"
  local FILES_DIR="$3"
  local APP_TARGET="$4"
  local PRODUCT_VERSION="$5"
  local MARKETING_VERSION="$6"

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
new_target = project.new_target(:app_extension, "$NEW_TARGET_NAME", 'iOS', '15.0')
app_target = project.targets.find { |t| t.name == "$APP_TARGET" }
puts "app target"
if app_target && new_target
  app_target.add_dependency(new_target)
end

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
  #config.build_settings['NSExtensionPointIdentifier'] = 'com.apple.keyboard-service'
  #config.build_settings['NSExtensionPrincipalClass'] = '\$(PRODUCT_MODULE_NAME).KeyboardViewController'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['PRODUCT_NAME'] = new_target.name
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "$BUNDLE_ID.appnomixkeyboard"
  config.build_settings['DEVELOPMENT_TEAM'] = development_team

  config.build_settings['CURRENT_PROJECT_VERSION'] = "$PRODUCT_VERSION"
  config.build_settings['MARKETING_VERSION'] = "$MARKETING_VERSION"

  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_FILE'] = "#{new_target.name}/Info.plist"
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = new_target.name
  config.build_settings['CONTENTS_FOLDER_PATH'] = "#{new_target.name}.appex"
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


project.save
puts "Added new custom keyboard extension target: #{new_target.name}"
EOF
}
