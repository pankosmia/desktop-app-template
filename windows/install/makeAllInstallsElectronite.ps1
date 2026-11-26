<#
.SYNOPSIS
    Creates Windows installation packages for the application.

.DESCRIPTION
    This script automates the build process for Windows installers:
    - Downloads Electron and zip releases for specified architectures
    - Processes and packages the files
    - Creates installation packages for each supported architecture
    - Currently supports x64 (Intel) and arm64 architecture

.NOTES
    Requires PowerShell and depends on:
    - getElectronRelease.ps1
    - makeInstallElectronite.ps1
    - app_config.json at the repo root (app.*, electronite.url for the selected tier)

.PARAMETER Tier
    Required. Builds all of the given tier from app_config.json: dev, qa, or main.
    - Must be listed in tiers.order.
    - Default is tiers.default

.PARAMETER Dev
    Specify -DevEnvRun "Y" when generating a development environment viewer.
    - Default is "N"
    - Unrelated to the "dev" tier.

.PARAMETER IsGHA
    Specify -IsGHA "N" when run locally to avoid a failed attempt to list github actions environment variables.
    IsGHA "N" also means that .exe will be built
    - Default is "Y" (Careful as default is Y on `bundle_app.ps1`.)

.PARAMETER FullInstall
    Specify -FullInstall $true for installing Electronite too; -FullInstall $false for updating all but Electronite (e.g., a development environment viewer update)
    - Default is $true

.PARAMETER -p
    Specify -p or -P for Portable App
#>
param(
    [string]$Tier,
    [string]$DevEnvRun = "N",
    [string]$IsGHA = "Y",
    [bool]$FullInstall = $true,
    [switch]$p
)

# Read app_config.json (repo root)
$APP_CONFIG_FILE = Join-Path $PSScriptRoot "..\..\app_config.json"
$APP_CONFIG = Get-Content -Path $APP_CONFIG_FILE -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

# Default for Tier is <tiers.default>
if (-not $PSBoundParameters.ContainsKey('Tier')) {
    $Tier = $APP_CONFIG.tiers.default
}

# Returns the value of the single entry whose branches include the tier.
function Get-TierValue {
    param($Entries, [string]$Key, [string]$TierName)
    $match = @($Entries | Where-Object { $_.branches -contains $TierName })
    if ($match.Count -ne 1) {
        throw "$Key must have exactly one entry for tier '$TierName' in app_config.json (found $($match.Count))."
    }
    return $match[0].value
}

try {
    # Tier is required (-Tier). No fallback. Checked here so a missing value fails with a clear error
    # instead of pausing for input as happens in ps1 if designated Mandatory.
    if (@($APP_CONFIG.tiers.order) -notcontains $Tier) {
        throw "-Tier is required and must be one of: $(@($APP_CONFIG.tiers.order) -join ', ') (got '$Tier')."
    }

    # Electronite download URLs, keyed "<platform>-<arch>"
    $electronUrls = Get-TierValue $APP_CONFIG.electronite.url "electronite.url" $Tier
}
catch {
    Write-Host "Error reading app_config.json: $_"
    exit 1
}

Write-Host "Tier is $Tier"

if ($IsGHA -ne 'N') {
  # show environment variables defined
  env
}

$CPU_ARCH = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
    "arm64"
} else {
    "x64"
}

# Loop through architectures
foreach ($ARCH in @("x64", "arm64")) {
    # Skip if not running on native architecture
    if ($ARCH -ne $CPU_ARCH) {
        Write-Host "Skipping $ARCH build on $CPU_ARCH machine (not applicable)."
        continue
    }
    Write-Host "Architecture: $ARCH"

    # Set download URL (electronite.url) and expected zip based on architecture
    $downloadElectronUrl = $electronUrls."win32-$ARCH"
    if (-not $downloadElectronUrl) {
        Write-Host "Error: electronite.url has no 'win32-$ARCH' entry for tier '$Tier' in app_config.json"
        exit 1
    }
    $expectedZip = "*-win-$ARCH-cli*.zip"

    # Get Electron release
    if ($FullInstall) {
        # Get Electron release
        Write-Host "Getting Electron release..."
        $electronResult = & "$PSScriptRoot\getElectronRelease.ps1" -downloadUrl $downloadElectronUrl -arch $ARCH -DevEnvRun $DevEnvRun
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to get Electron release files at $downloadElectronUrl"
            exit 1
        }
    } else {
        Write-Host "Skipping Electron download/release step (not needed)."
    }

    if ($DevEnvRun -ne 'Y') {
      # verify zip
      If (-Not (Test-Path ..\..\releases\windows\$expectedZip)) {
          echo "Error: Missing windows .zip release"
          exit 1
      }
    }

    # Run makeInstallElectronite PowerShell script
    if ($FullInstall) {
        Write-Host "`n"
        Write-Host "     *****************************************"
        Write-Host "     * Running makeInstallElectronite.ps1... *"
        Write-Host "     * Wait for the prompt.                  *"
        Write-Host "     *****************************************"
        Write-Host "`n"
    }
    $makeInstallElectronitePath = Join-Path $PSScriptRoot "makeInstallElectronite.ps1"
    if (-not (Test-Path $makeInstallElectronitePath)) {
        Write-Host "Error: makeInstallElectronite.ps1 not found at $makeInstallElectronitePath"
        exit 1
    }

    $installArgs = @{
        Tier        = $Tier
        DevEnvRun   = $DevEnvRun
        arch        = $ARCH
        FullInstall = $FullInstall
    }

    if ($p.IsPresent) {
        $installArgs.p = $true
    }

    $result = & $makeInstallElectronitePath @installArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: makeInstallElectronite.ps1 failed with exit code $LASTEXITCODE"
        exit 1
    }
}

# Remove temporary electronite files from local dev viewer build.
if ($DevEnvRun -eq 'Y') {
  Remove-Item -Path "..\viewer\electron" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path "..\viewer\electron.*" -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Local Dev Electronite Viewer has been successfully built."
}

if ($DevEnvRun -ne 'Y') {
  Write-Host "All architectures built successfully"
}

exit 0
