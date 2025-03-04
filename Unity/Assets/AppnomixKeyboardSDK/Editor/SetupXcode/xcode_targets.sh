#!/bin/bash

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
puts "Added new custom keyboard extension target: #{new_target.name}"
EOF
}
