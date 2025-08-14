<#
.SYNOPSIS
    Creates Windows installation packages for the application.

.DESCRIPTION
    This script automates the build process for Windows installers:
    - Downloads Electron and zip releases for specified architectures
    - Processes and packages the files
    - Creates installation packages for each supported architecture
    - Currently supports Intel64 architecture (ARM64 support is commented out)

.NOTES
    Requires PowerShell and depends on:
    - getElectronRelease.ps1
    - makeInstallElectroniteFromZip.ps1
#>
param(
    [string]$Dev,
    [string]$IsGHA
)

# get environment variables from app_config.env
get-content ..\..\app_config.env | foreach {
  $name, $value = $_.split('=')
  if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('#')) {
    # skip empty or comment line in ENV file
    return
  }
  Set-Variable -Name $name -Value $value
  # Write-Host "Env $name=$value"
}

$env:APP_NAME=$APP_NAME.Trim("'")
$env:APP_VERSION=$APP_VERSION

if ($IsGHA -ne 'N') {
  # show environment variables defined
  env
}

# Define URLs for different architectures
$ElectronArm64 = "https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-win32-arm64.zip"
$ElectronIntel64 = "https://github.com/unfoldingWord/electronite/releases/download/v37.1.0-graphite/electronite-v37.1.0-graphite-win32-x64.zip"

# Loop through architectures
# foreach ($ARCH in @("intel64", "arm64")) {

foreach ($ARCH in @("intel64")) {
    Write-Host "Building for architecture: $ARCH"

    # Set download URLs based on architecture
    $downloadElectronUrl = $ElectronIntel64
    $expectedZip = "*-windows-*.zip"

    if ($ARCH -eq "arm64") {
        $downloadElectronUrl = $ElectronArm64
        $expectedZip = "*-windows-*.zip" # TODO need to set for arm
    }

    # Get Electron release
    Write-Host "Getting Electron release..."
    $electronResult = & "$PSScriptRoot\getElectronRelease.ps1" -downloadUrl $downloadElectronUrl -arch $ARCH
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to get Electron release files at $downloadElectronUrl"
        exit 1
    }

    # verify zip
    If (-Not (Test-Path ..\..\releases\windows\$expectedZip)) {
        echo "Error: Missing windows .zip release"
        exit 1
    }

    # Make install from zip
    Write-Host "Creating install package..."
    $zipPath = Resolve-Path "..\..\releases\windows\$expectedZip"
    if ($Dev -eq 'Y') {
      $installResult = & "$PSScriptRoot\makeInstallElectroniteFromZip.ps1" -Dev "Y" -zipPath $zipPath -destinationFolder "..\temp\release" -arch $ARCH
    } else {
      $installResult = & "$PSScriptRoot\makeInstallElectroniteFromZip.ps1" -zipPath $zipPath -destinationFolder "..\temp\release" -arch $ARCH
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Build failed for architecture $ARCH"
        exit 1
    }
}

Write-Host "All architectures built successfully"