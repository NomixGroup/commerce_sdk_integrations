#!/bin/bash

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
      file_ref = target.frameworks_build_phase.add_file_reference(framework_ref)
      puts "Added framework reference to target: #{target_name}"
    else
      puts "Framework reference already exists in target: #{target_name}"
    end

    # Embed and sign the framework
    embed_phase = target.copy_files_build_phases.find { |phase| phase.name == 'Embed Frameworks' } ||
                  target.new_copy_files_build_phase('Embed Frameworks')

    embed_phase.symbol_dst_subfolder_spec = :frameworks # Embed frameworks into the Frameworks folder

    unless embed_phase.files_references.include?(framework_ref)
      build_file = embed_phase.add_file_reference(framework_ref)
      build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
      puts "Embedded and set CodeSignOnCopy for framework in target: #{target_name}"
    else
      puts "Framework already embedded and signed in target: #{target_name}"
    end
  else
    puts "Target not found: #{target_name}"
  end
end

# Save the project file
project.save

EOF
}
