
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

.PARAMETER Dev
Specify -DevEnvRun "Y" when generating a development viewer.
- Default is "N"
#>

# Check if filename and destination are provided as arguments
param(
    [string]$downloadUrl,
    [string]$arch,
    [string]$DevEnvRun
)

# downloadUrl is required (-downloadUrl). Checked here so a missing value fails with a clear error
# instead of pausing for input as happens in ps1 if designated Mandatory.
if (-not $downloadUrl) {
    Write-Host "Error: downloadUrl is required: -downloadUrl:<url>"
    exit 1
}

# arch is required (-arch). Checked here so a missing value fails with a clear error
# instead of pausing for input as happens in ps1 if designated Mandatory.
if (-not $arch) {
    Write-Host "Error: arch is required: -arch:arm64 or -arch:x64"
    exit 1
}

# DevEnvRun is required (-devEnvRun). Checked here so a missing value fails with a clear error
# instead of pausing for input as happens in ps1 if designated Mandatory.
if (-not $DevEnvRun) {
    Write-Host "Error: DevEnv is required: -DevEnvRun:Y or -DevEnvRun:N"
    exit 1
}

if ($DevEnvRun -eq 'Y') {
  $pkgDir = "viewer"
} else {
    $pkgDir = "temp"
}

$testDir = "..\$pkgDir\electron.$arch\electron.exe"
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
$destFolder = "..\$pkgDir\electron\$arch"
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
$unzipDest = "..\$pkgDir\electron.$arch"
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
