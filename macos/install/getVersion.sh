#!/bin/sh

# Synopsis:
#   getVersion.sh - Extract version number from filename and set it as environment variable
#
# Description:
#   This script extracts a version number from a provided filename that follows the pattern
#   'v[X].[Y].[Z]' (e.g., 'myfile_v1.2.3.pkg'). The extracted version is printed and set
#   as an environment variable APP_VERSION.
#
# Parameters:
#   $1 - Input filename (required) - Full path to the file containing version number
#
# Return values:
#   0 - Success
#   1 - Error (missing filename argument or unable to extract version)
#
# Environment variables:
#   Sets APP_VERSION with the extracted version number (without 'v' prefix)


# Check if a filename is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

# File name provided as the first argument (including path)
filename="$1"

# Extract version number
version=$(echo "$filename" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')

# remove the leading 'v'
version=${version#v}

# Check if a version was extracted; if not, show an error
if [ -z "$version" ]; then
  echo "Error: Unable to extract version from file name '$filename'."
  exit 1
fi

# Print the extracted version
echo "Extracted version: $version"

# Set APP_VERSION environment variable
export APP_VERSION="$version"

