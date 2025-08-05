#!/bin/sh

# Synopsis:
#   makeAllInstallsElectronite.sh
#
# Description:
#   This script automates the build process for the application on macOS,
#   creating installation packages for both Intel (x64) and ARM64 architectures.
#   It downloads the required Electron and zip releases, and processes them
#   into installable packages.
#
# Parameters:
#   None - All URLs and architectures are hardcoded in the script
#
# Return Values:
#   0 - Success, all architectures built successfully
#   1 - Error occurred during download or build process
#

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

# export environment variable
echo "FILE_APP_NAME=$FILE_APP_NAME"
export FILE_APP_NAME="$FILE_APP_NAME"
echo "APP_NAME=$APP_NAME" 
export APP_NAME="$APP_NAME"
echo "APP_VERSION=$APP_VERSION"
export APP_VERSION="$APP_VERSION"

ElectronArm64="https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-darwin-arm64.zip"
ElectronIntel64="https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-darwin-x64.zip"

# Detect current CPU architecture
CPU_ARCH=$(uname -m)
if [ "$CPU_ARCH" = "x86_64" ]; then
    CPU_ARCH="intel64"
elif [ "$CPU_ARCH" = "arm64" ]; then
    CPU_ARCH="arm64"
else
    echo "Error: Unsupported CPU architecture: $CPU_ARCH, default to intel64"
    CPU_ARCH="intel64"
fi

# Loop through creating installs for both arm64 and intel64
for ARCH in "intel64" "arm64"; do
    # Skip if not running on native architecture
    if [ "$ARCH" != "$CPU_ARCH" ]; then
        echo "Skipping $ARCH build on $CPU_ARCH machine"
        continue
    fi
  
    echo "Building for architecture: $ARCH"
  
    downloadElectronUrl="$ElectronIntel64"
    expectedZip="*-intel64-*.zip"
    if [ "$ARCH" = "arm64" ]; then
        downloadElectronUrl="$ElectronArm64"
        expectedZip="*-arm64-*.zip"
    fi

    ./getElectronRelease.sh  $downloadElectronUrl $ARCH
    
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get Electron release files at downloadElectronUrl - $?"
        exit 1
    fi
    
    # Check if zip file exists
    zipFile=$(ls -1 ../../releases/macos/$expectedZip | head -n1)
    if [ -z "$zipFile" ]; then
        echo "Error: zip file not found in ../../releases/macos/"
        exit 1
    fi
    
    # unzip the install files and create mac install package
    ./makeInstallFromZipElectronite.sh  $zipFile ../temp/release $ARCH
    
    if [ $? -ne 0 ]; then
        echo "Error: Build failed for architecture $ARCH"
        exit 1
    fi
done

echo "Build completed for $CPU_ARCH architecture"
