#!/bin/bash

# check if Ruby is installed
check_ruby_installed() {
  if command -v ruby >/dev/null 2>&1; then
    echo "Ruby is already installed."
    return 0
  else
    echo "Ruby is not installed."
    return 1
  fi
}

# install Ruby on macOS
install_ruby() {
  echo "Installing Ruby..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install ruby
  echo "Ruby installation completed."

  # Ensure the required gems are installed
  GEMS=("xcodeproj" "plist" "json")

  for GEM in "${GEMS[@]}"; do
    if gem list -i "$GEM" >/dev/null 2>&1; then
        echo "Gem '$GEM' is already installed."
    else
        echo "Installing gem '$GEM'..."
        gem install "$GEM"
        gem install "$GEM" --user-install
    fi
  done
}

# Main script logic
if ! check_ruby_installed; then
  install_ruby
fi
