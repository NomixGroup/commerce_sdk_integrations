update_main_mm() {
    local main_file="$1"  # Path to main.mm file

    # Ensure the file exists
    if [ ! -f "$main_file" ]; then
        echo "Error: main.mm not found at $main_file"
        return 1
    fi

    echo "Checking and updating $main_file..."

    # Add #import "Unity.h" if it's not already present
    if ! grep -q '#import "Unity-Swift.h"' "$main_file"; then
        echo "Adding Unity import..."
        sed -i '' '1s|^|#import "Unity-Swift.h"\n|' "$main_file"
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
