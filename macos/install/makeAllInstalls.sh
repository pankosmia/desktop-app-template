#!/bin/sh

# This script uses the APP_NAME environment variables as defined in app_config.env
source ../../app_config.env

# Confirm the APP_NAME environment variables is set
if [ -z "$APP_NAME" ]; then
    echo "Error: APP_NAME environment variable is not set."
    exit 1
fi

# Use lower case app name in filename -- zsh: ${APP_NAME:l}  -- bsh: ${APP_NAME,,} -- sh: $(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
FILE_APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
# Replace spaces with a dash (-) in filename
FILE_APP_NAME=${FILE_APP_NAME// /-}
# Set FILE_APP_NAME environment variable
export FILE_APP_NAME="$FILE_APP_NAME"

# Loop through creating installs for both arm64 and intel64
for ARCH in "arm64" "intel64"; do
    echo "Building for architecture: $ARCH"

    # unzip install files and create mac install package
    chmod +x makeInstallFromBuild.sh
    ./makeInstallFromBuild.sh  ../../releases/macos/${FILE_APP_NAME}*.zip ../release $ARCH
    # cp ../release/$ARCH/*.pkg ../build

    if [ $? -ne 0 ]; then
        echo "Error: Build failed for architecture $ARCH"
        exit 1
    fi
done

echo "All architectures built successfully"