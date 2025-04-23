#!/bin/bash

update_main_mm() {
    local main_file="$1"  # Path to main.mm file
    local unity_import_prefix="$2"

    # Ensure the file exists
    if [ ! -f "$main_file" ]; then
        echo "Error: main.mm not found at $main_file"
        return 1
    fi

    echo "Checking and updating $main_file..."

    # Construct the configurable import statement
    local unity_import="#import \"${unity_import_prefix}-Swift.h\""

    # Add the import statement if it's not already present
    if ! grep -q "$unity_import" "$main_file"; then
        echo "Adding Unity import: $unity_import..."
        sed -i '' "1s|^|$unity_import\n|" "$main_file"
    else
        echo "Unity import already exists."
    fi

    # Add AppnomixKeyboardSDK setup call inside main() if missing
    if ! grep -q '\[AppnomixKeyboardSDK instance\] setup' "$main_file"; then
        echo "Adding AppnomixKeyboardSDK setup call..."
        sed -i '' '/id ufw = UnityFrameworkLoad();/a\
        \ \ \ \ [[AppnomixKeyboardSDK instance] setup];
        ' "$main_file"
    else
        echo "AppnomixKeyboardSDK setup call already exists."
    fi

    echo "main.mm successfully modified!"
}
