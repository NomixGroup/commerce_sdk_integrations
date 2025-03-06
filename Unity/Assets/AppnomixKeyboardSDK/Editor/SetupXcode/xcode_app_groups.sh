#!/bin/bash

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
