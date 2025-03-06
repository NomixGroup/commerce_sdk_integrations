

update_keyboard_content_file() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "Error: File '$file_path' not found."
        return 1
    fi

    echo "Customizing '$file_path'..."

    echo "$BUNDLE_NAME=$BUNDLE_NAME"

    # Use `sed` to replace the string
    sed -i '' "s/YOUR_CLIENT_ID_HERE/$YOUR_CLIENT_ID/g" "$file_path"
    sed -i '' "s/YOUR_AUTH_TOKEN_HERE/$YOUR_AUTH_TOKEN/g" "$file_path"
    sed -i '' "s/YOUR_APP_NAME_HERE/$BUNDLE_NAME/g" "$file_path"
    sed -i '' "s/YOUR_APP_GROUP_ID_HERE/$APP_GROUPS_NAME/g" "$file_path"
    sed -i '' "s/YOUR_APP_SCHEME_HERE/$YOUR_APP_SCHEME/g" "$file_path"

    echo "Replacement done!"
}

