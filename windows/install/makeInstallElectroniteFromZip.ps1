<#
.SYNOPSIS
Creates a Windows installer from a zip file containing application files.  
The resulting installer is in `releases\windows\$arch`

.DESCRIPTION
This PowerShell script processes a zip file containing application files, extracts its contents,
and creates a Windows installer. It performs the following steps:
1. Extracts version information from the zip filename
2. Unzips the contents to a temporary directory
3. Copies files to the build directory
4. Runs makeInstall.ps1 to create the final installer
5. Verifies the installer was created successfully
6. Cleans up temporary files

.PARAMETER zipPath
Path to the zip file containing the application files

.PARAMETER destinationFolder
Destination folder where the installer will be created

.PARAMETER arch
Target architecture for the installer (e.g., x64, x86)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$zipPath
,
    
    [Parameter(Mandatory=$true)]
    [string]$destinationFolder,
    
    [Parameter(Mandatory=$true)]
    [string]$arch
)

Write-Host "Processing '$zipPath
'"

# Set destination path
$destination = Join-Path $destinationFolder $arch

# Check if a version was extracted
if ([string]::IsNullOrEmpty($env:APP_VERSION)) {
    Write-Host "Error: Unable to extract version from file name '$zipPath
'."
    exit 1
}

# Create temporary directory
$TEMP_DIR = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null
Write-Host "Created temporary directory: $TEMP_DIR"

# Unzip the file
try {
    Expand-Archive -Path $zipPath -DestinationPath $TEMP_DIR -Force
    Write-Host "Successfully unzipped to: $TEMP_DIR"
    Write-Host "Contents of $TEMP_DIR"
    Get-ChildItem -Path $TEMP_DIR -Recurse | ForEach-Object { Write-Host $_.FullName }
    
}
catch {
    Write-Host "Error: Failed to unzip '$zipPath
' - $($_.Exception.Message)"
    Remove-Item -Path $TEMP_DIR -Recurse -Force
    exit 1
}

# Clean and create build directory
$buildPath = "..\build"
if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildPath | Out-Null

# Copy files from temp to build
Copy-Item -Path "$TEMP_DIR\*" -Destination $buildPath -Recurse -Force

# Run makeInstallElectronite PowerShell script
Write-Host "Running makeInstallElectronite.ps1..."
$makeInstallElectronitePath = Join-Path $PSScriptRoot "makeInstallElectronite.ps1"
if (-not (Test-Path $makeInstallElectronitePath)) {
    Write-Host "Error: makeInstallElectronite.ps1 not found at $makeInstallElectronitePath"
    Remove-Item -Path $TEMP_DIR -Recurse -Force
    exit 1
}

$result = & "$makeInstallElectronitePath" -arch $arch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: makeInstallElectronite.ps1 failed with exit code $LASTEXITCODE"
    Remove-Item -Path $TEMP_DIR -Recurse -Force
    exit 1
}

# Verify installer exists
$releaseFolder = "..\..\releases\windows\$arch"
$installerExists = Get-ChildItem -Path "$releaseFolder" -Filter "*.exe"
if (-not $installerExists) {
    Write-Host "Error: *.exe not found in $releaseFolder"
    exit 1
}

# Clean up temp directory
Remove-Item -Path $TEMP_DIR -Recurse -Force
exit 0