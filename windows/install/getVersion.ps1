<#
.SYNOPSIS
    Extracts version number from a filename and sets it as APP_VERSION environment variable.

.DESCRIPTION
    This PowerShell script is part of the Windows installation process.
    It extracts a version number from an input filename using regex pattern matching
    and sets it as an environment variable. The version number must be in the format
    'vX.Y.Z' where X, Y, and Z are numeric values. This script is used by the Inno
    Setup installer to determine the application version during the build process.

.PARAMETER filename
    The input filename containing a version string in the format 'vX.Y.Z'.
    Example: 'setup_v1.2.3.exe' will extract '1.2.3'.

.NOTES
    Exit Codes:
    - 0: Success
    - 1: Failed to extract version number from filename
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$filename
)

# Extract version number using regex
$version = if ($filename -match 'v(\d+\.\d+\.\d+)') {
    $matches[1]
} else {
    $null
}

# Check if a version was extracted
if ([string]::IsNullOrEmpty($version)) {
    Write-Host "Error: Unable to extract version from file name '$filename'."
    exit 1
}

# Print the extracted version
Write-Host "Extracted version: $version"

# Set APP_VERSION environment variable
$env:APP_VERSION = $version
