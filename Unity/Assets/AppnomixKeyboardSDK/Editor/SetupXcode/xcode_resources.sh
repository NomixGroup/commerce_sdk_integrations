#!/bin/bash

# Function to add an xcassets folder to a target
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
