# This script uses app.version from app_config.json for the selected tier.

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_viewer.ps1
# with the optional arguments of: .\bundle_viewer.ps1 -ServerOff "y"
# and: .\bundle_viewer.ps1 -Tier dev|qa|main

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
    - makeAllInstallsElectronite.ps1
    - getElectronRelease.ps1
    - makeInstallElectronite.ps1

.PARAMETER ServerOff
    Specify -ServerOff "y" to indicate the server is off, thereby avoiding being asked to confirm it is off.

.PARAMETER IsGHA
    Specify -IsGHA "Y" when run from GitHub Actions.
      - keeps bundle_zip.ps1 from being run as our GHA scripts requests it separately
      - keeps `app_setup.bat`, `pnpm install` and 'node build.js` from being re-run as they have already run in earlier steps in windows-build-steps.yml
    - Default is "N"  (Careful as default is Y on `makeAllInstallsEletronite.ps1`.)

.PARAMETER Tier
    dev, qa, or main. Defaults to APP_TIER, then BRANCHES, then tiers.default in app_config.json.

.PARAMETER -p
    Specify -p for Portable App
#>

param(
    [string]$ServerOff,
    [string]$IsGHA = "N",
    [string]$Tier,
    [switch]$p
)

if ($ServerOff -eq 'Y' -or $ServerOff -eq 'y') {
  $answer = $ServerOff
} else {
  echo "`n"
  $answer = Read-Host "     Is the server off? [Y/n]"
}

if ($answer -eq 'Y' -Or $answer -eq '') {
    echo "`n"
    echo "Continuing..."
    echo "`n"

  # Load app_config.json and resolve values for the selected tier
  $cfg = Get-Content ..\..\app_config.json -Raw | ConvertFrom-Json

  if (-not $Tier) { $Tier = $env:APP_TIER }
  if (-not $Tier) { $Tier = $env:BRANCHES }
  if (-not $Tier) { $Tier = $cfg.tiers.default }
  $Tier = $Tier.ToLower()
  if ($cfg.tiers.order -notcontains $Tier) {
    throw "Unknown tier '$Tier'. Expected one of: $($cfg.tiers.order -join ', ')"
  }

  $m = @($cfg.app.version | Where-Object { $_.branches -contains $Tier })
  if ($m.Count -ne 1) { throw "app.version must have exactly one entry for tier '$Tier', found $($m.Count)" }
  $APP_VERSION = $m[0].value

  # Make the tier visible to child scripts
  $env:APP_TIER = $Tier

  $TEMP_DIR = "..\temp"
    if (Test-Path $TEMP_DIR) {
        Write-Host "Deleting previous build..."
        Write-Host "`n"
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

  if ($IsGHA -ne 'Y') {
    # The bundle_zip script will ensure the latest is checked out, the clone is installed, and the app_setup script is run
    echo "`n"
    echo "Bundling Zip..."
    echo "  - updates the build environment for the Electronite package build,"
    echo "  - and creates a zip bundle that parallels the Electronite package."
    .\bundle_zip.ps1 -ServerOff "Y" -Tier $Tier
  }

  echo "`n"
  echo "Tier is $Tier"
  echo "Version is $APP_VERSION"
  echo "`n"

  Write-Host "`n"
  Write-Host "`n"
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`"Getting Electron release`" downloads an approximately 120 MB file." -f cyan;
  Write-Host "Please wait patiently for the highlighted download process to complete..." -f cyan;
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`n"

  $installArgs = @{
      IsGHA = $IsGHA
  }

  if ($p.IsPresent) {
      $installArgs['p'] = $true
  }

  & ..\install\makeAllInstallsElectronite.ps1 @installArgs

} elseif ($answer -eq 'N') {
    echo "`n"
    echo "     Turn the server off by exiting the terminal window in which it is running, then re-run this script while the server is off."
    echo "`n"
} else {
    echo "`n"
    echo """$answer"" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
    .\bundle_viewer.ps1 -IsGHA $IsGHA -Tier $Tier -p:$p
}
