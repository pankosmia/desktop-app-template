#!/bin/sh

# Script: makeInstallFromZipElectronite.sh
# Synopsis: Creates a macOS installer package from a zip file containing application files
#
# Description: This script automates the process of creating a macOS installer package (.pkg)
# from a zip file containing application files. It extracts the version number from the zip
# filename, creates temporary directories, processes the files, and generates an installer
# using makeInstallElectronite.sh.
#
# Requirements:
# - macOS operating system
# - zip/unzip command line tools
# - makeInstallElectronite.sh script in the same directory
# - getVersion.sh script in the same directory
# - Write permissions in the target directories
#
# Parameters:
#   $1 (filename) - Path to the source zip file containing application files
#   $2 (destination-folder) - Directory where the final installer package will be placed
#   $3 (arch) - Target architecture, either 'arm64' or 'intel64'
#   $4 -d indicates generation of a development viewer (optional)
#
# Returns:
#   0 - Success
#   1 - Error (invalid parameters or processing failure)
#   
# Generated files will be placed in <destination-folder>/<arch>/<app-name>_installer_*.pkg

# Check if filename and destination are provided as an argument
if [ -z "$3" ]; then
  echo "Usage: $0 <filename> <destination-folder> <arch>"
  exit 1
fi

# get arguments
filename="$1"
destination="$2/$3"
arch="$3"
devRun="${4:-no}" # This is a development viewer run if $4 is -d

echo "Processing '$filename'"

## do source so environment variables persist
#source ./getVersion.sh $filename
#
## Check if a version was extracted; if not, show an error
#if [ -z "$APP_VERSION" ]; then
#  echo "Error: Unable to extract version from file name '$filename'."
#  exit 1
#fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Unzip the file
if ! unzip "$filename" -d "$TEMP_DIR"; then
  echo "Error: Failed to unzip '$filename'"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "Successfully unzipped to: $TEMP_DIR"

if ! [[ $devRun =~ ^(-d) ]]; then
  # Clean and create build directory
  rm -rf ../build
  mkdir -p ../build
  # Copy files from temp to build
  cp -R "$TEMP_DIR"/* ../build/
fi

# Run makeInstallElectronite Shell script
echo "Running makeInstallElectronite.sh..."
./makeInstallElectronite.sh $arch $devRun

echo "Files at ../../releases/macos/"
ls -als ../../releases/macos/

