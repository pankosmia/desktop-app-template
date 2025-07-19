
<#
.SYNOPSIS
Downloads and extracts Electron release packages for specified architecture.

.DESCRIPTION
This PowerShell script downloads Electron release packages from a provided URL for a specific architecture.
It checks if the package already exists, downloads the zip file if needed, and extracts it to a temporary directory.
The script handles both the download and extraction process with error checking.

.PARAMETER downloadUrl
The URL to download the Electron release package from.

.PARAMETER arch
The target architecture (e.g., x64, arm64) for the Electron package.
#>

# Check if filename and destination are provided as arguments
param(
    [Parameter(Mandatory=$true)]
    [string]$downloadUrl,

    [Parameter(Mandatory=$true)]
    [string]$arch
)

$testDir = "..\temp\electron.$arch\electron.exe"
Write-Host "Checking for $testDir"
if (Test-Path $testDir) {
    Write-Host "electron.exe already exists for $arch"
    exit 0
}

# Extract filename from URL
$filename = Split-Path $downloadUrl -Leaf
Write-Host "filename is $filename"

Write-Host "Fetching for architecture: $arch from $downloadUrl"

# Create directory for downloaded files
$destFolder = "..\temp\electron\$arch"
New-Item -ItemType Directory -Force -Path $destFolder | Out-Null

# Download zip file
$tempName = "$destFolder\temp.zip"
Write-Host "Downloading $arch package to $tempName"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempName
}
catch {
    Write-Host "Error: Failed to download $downloadUrl package to $tempName - $($_.Exception.Message)"
    exit 1
}

# Create destination directory
$unzipDest = "..\temp\electron.$arch"
if (Test-Path $unzipDest) {
    Remove-Item -Path $unzipDest -Recurse -Force
}

# Unzip the file
try {
    Expand-Archive -Path $tempName -DestinationPath $unzipDest -Force
    Write-Host "Successfully unzipped to: $unzipDest"
}
catch {
    Write-Host "Error: Failed to unzip to '$unzipDest' - $($_.Exception.Message)"
    exit 1
}

exit 0
