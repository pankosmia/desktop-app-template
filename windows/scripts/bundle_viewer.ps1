# This script uses app.version from app_config.json for the selected tier.

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_viewer.ps1 -Tier dev|qa|main
# with the optional argument of: .\bundle_viewer.ps1 -Tier <tier> -ServerOff "y"

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
    Required. Builds all of the given tier from app_config.json: dev, qa, or main.
    - Must be listed in tiers.order. No default, no fallback.

.PARAMETER -p
    Specify -p for Portable App
#>

param(
    [string]$ServerOff,
    [string]$IsGHA = "N",
    [string]$Tier,
    [switch]$p
)

# Returns the value of the single entry whose branches include the tier.
function Get-TierValue {
    param($Entries, [string]$Key, [string]$TierName)
    $match = @($Entries | Where-Object { $_.branches -contains $TierName })
    if ($match.Count -ne 1) {
        throw "$Key must have exactly one entry for tier '$TierName' in app_config.json (found $($match.Count))."
    }
    return $match[0].value
}

# All relative paths below assume windows\scripts.
Push-Location $PSScriptRoot

try {
    # Load app_config.json and resolve values for the selected tier -- before asking anything.
    try {
        $config = Get-Content -Path (Join-Path $PSScriptRoot "..\..\app_config.json") -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

        # Tier is required (-Tier). No default, no fallback. Checked here so a missing value fails with a clear error
        # instead of pausing for input as happens in ps1 if designated Mandatory.
        if (@($config.tiers.order) -notcontains $Tier) {
            throw "-Tier is required and must be one of: $(@($config.tiers.order) -join ', ') (got '$Tier')."
        }

        $APP_VERSION = [string](Get-TierValue $config.app.version "app.version" $Tier)
    }
    catch {
        Write-Host "Error: $_"
        exit 1
    }

    # Confirm the server is off
    $answer = $ServerOff
    while ($answer -ne 'Y' -and $answer -ne 'N') {
        if ($null -ne $answer -and $answer -ne '') {
            echo "`n"
            echo """$answer"" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
        }
        echo "`n"
        $answer = Read-Host "     Is the server off? [Y/n]"
        if ($answer -eq '') { $answer = 'Y' }
    }

    if ($answer -eq 'N') {
        echo "`n"
        echo "     Turn the server off by exiting the terminal window in which it is running, then re-run this script while the server is off."
        echo "`n"
        exit 1
    }

    echo "`n"
    echo "Continuing..."
    echo "`n"

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
        & .\bundle_zip.ps1 -ServerOff "Y" -Tier $Tier
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: bundle_zip.ps1 failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
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
        Tier  = $Tier
    }

    if ($p.IsPresent) {
        $installArgs['p'] = $true
    }

    & ..\install\makeAllInstallsElectronite.ps1 @installArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: makeAllInstallsElectronite.ps1 failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    exit 0
}
finally {
    Pop-Location
}
