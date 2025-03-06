#!/bin/bash

# add NSUserTrackingUsageDescription to Info.plist
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
  else
    puts "Error: Info.plist file not found at #{info_plist_path}"
    exit 1
  end

EOF
}
