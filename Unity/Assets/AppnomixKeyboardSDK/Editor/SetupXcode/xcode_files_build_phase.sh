#!/bin/bash

# Function to add a Copy Files build phase to a target in an Xcode project
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
