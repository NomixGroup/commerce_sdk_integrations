#!/bin/bash

# Function to extract project versions based on target name
get_project_versions() {
    local xcodeproj_path="$1"   # Path to .xcodeproj file
    local target_name="$2"      # Target name

    if [ -z "$xcodeproj_path" ] || [ -z "$target_name" ]; then
        echo "Usage: get_project_versions <path_to_xcodeproj> <target_name>"
        return 1
    fi

    ruby <<EOF
require 'xcodeproj'
require 'plist'

# Open the Xcode project
project_path = "$xcodeproj_path"
target_name = "$target_name"

project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }

if target.nil?
  puts "Error: Target '#{target_name}' not found in project."
  exit 1
end

# Get the Info.plist path from build settings
info_plist_file_setting = target.resolved_build_setting('INFOPLIST_FILE')

info_plist_file = if info_plist_file_setting.is_a?(Hash)
                    info_plist_file_setting['Release'] || info_plist_file_setting.values.first
                  else
                    info_plist_file_setting
                  end

# Validate Info.plist file existence
if info_plist_file.nil? || !File.exist?(info_plist_file)
  puts "Error: Info.plist file not found for target '#{target_name}'."
  exit 1
end

# Read Info.plist
plist = Plist.parse_xml(info_plist_file)
current_project_version = plist['CFBundleVersion'] || 'Unknown'
marketing_version = plist['CFBundleShortVersionString'] || 'Unknown'

# Print results for Bash
puts "PROJECT_VERSION=#{current_project_version}"
puts "MARKETING_VERSION=#{marketing_version}"
EOF
}
