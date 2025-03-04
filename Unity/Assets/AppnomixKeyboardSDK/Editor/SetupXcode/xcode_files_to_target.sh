#!/bin/bash

# Function to add files to a specified group in an Xcode project
add_files_to_target() {
  if [ "$#" -ne 4 ]; then
    echo "Usage: add_files_to_target <path_to_xcodeproj> <target_name> <group_name> <files_directory>"
    return 1
  fi

  local XCODEPROJ_PATH="$1"
  local TARGET_NAME="$2"
  local GROUP_NAME="$3"
  local FILES_DIR="$4"

  echo "Adding files to target: $TARGET_NAME under group: $GROUP_NAME from directory: $FILES_DIR"

  ruby <<EOF
require 'xcodeproj'

project_path = "$XCODEPROJ_PATH"
target_name = "$TARGET_NAME"
group_name = "$GROUP_NAME"
files_dir = "$FILES_DIR"

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }
if target.nil?
  puts "Error: Target '#{target_name}' not found."
  exit 1
end

# Search for 'MainApp' group anywhere in the project hierarchy
main_app_group = project.main_group.recursive_children.find { |group| group.display_name == group_name }

# If 'MainApp' group does not exist, create it under the main project structure
if main_app_group.nil?
  puts "Creating missing group '#{group_name}' under main project."
  main_app_group = project.main_group.new_group(group_name)
end

# Ensure the files directory exists
unless Dir.exist?(files_dir)
  puts "Error: Files directory '#{files_dir}' not found."
  exit 1
end

# Add all files from the given directory to the 'MainApp' group
Dir.glob("#{files_dir}/*.{swift,m,h}") do |file|
  file_name = File.basename(file)
  file_ref = main_app_group.find_file_by_path(file_name) || main_app_group.new_reference(file)

  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added file: #{file_name} to group: #{group_name} under target: #{target_name}"
  else
    puts "File already exists: #{file_name}"
  end
end

# Save changes
project.save
puts "Updated project file successfully."
EOF
}
