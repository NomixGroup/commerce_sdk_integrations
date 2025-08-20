#!/bin/bash

get_bundle_name() {
    local project_path="$1"  # Path to the directory containing Info.plist

    ruby <<EOF
require 'plist'

info_plist_path = File.join('$project_path', 'Info.plist')

if !File.exist?(info_plist_path)
  puts "Error: Info.plist not found at #{info_plist_path}"
  exit 1
end

plist = Plist.parse_xml(info_plist_path)

if plist.nil? || !plist.key?('CFBundleDisplayName')
  puts "Error: CFBundleDisplayName not found in Info.plist"
  exit 1
end

puts plist['CFBundleDisplayName']
EOF
}