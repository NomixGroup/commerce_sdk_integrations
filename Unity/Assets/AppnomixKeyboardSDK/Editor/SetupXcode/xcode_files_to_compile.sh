#!/bin/bash

add_file_to_compile_sources() {
  if [ "$#" -ne 3 ]; then
    echo "Usage: add_file_to_compile_sources <path_to_xcodeproj> <target_name> <file_path>"
    return 1
  fi

  local XCODEPROJ_PATH="$1"  # Path to .xcodeproj
  local TARGET_NAME="$2"      # Target name in Xcode
  local FILE_PATH="$3"        # Full path to the file to be added

  echo "Adding '$FILE_PATH' to Compile Sources in target: '$TARGET_NAME'"

  ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
target_name = "$TARGET_NAME"
file_path = "$FILE_PATH"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Error: Target '#{target_name}' not found in project."
  exit 1
end

# Get the main group (top-level project group)
main_group = project.main_group

# Ensure the file is inside a proper group
group_path = File.dirname(file_path)
group = main_group.find_subpath(group_path, true)
group.set_source_tree('<group>')

# Find the file reference correctly
file_name = File.basename(file_path)
file_ref = group.files.find { |f| f.path == file_name }

# If the file reference doesn't exist, create it
if file_ref.nil?
  puts "Creating new file reference for '#{file_name}' in group '#{group.display_name}'"
  file_ref = group.new_reference(file_path)
end

# Ensure the file is added to Compile Sources (PBXSourcesBuildPhase)
source_build_phase = target.source_build_phase
if source_build_phase.files_references.include?(file_ref)
  puts "File '#{file_name}' is already in Compile Sources."
else
  source_build_phase.add_file_reference(file_ref)
  puts "Added '#{file_name}' to Compile Sources in target '#{target_name}'."
end

# Save changes
project.save
puts "Xcode project updated successfully!"
EOF
}
