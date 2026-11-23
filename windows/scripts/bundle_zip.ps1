# This script uses app.name and app.version from app_config.json for the selected tier.

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_zip.ps1 -Tier dev|qa|main
# with the optional arguments of: `.\bundle_zip.ps1 -Tier <tier> -ServerOff "Y"` or: `.\bundle_zip.ps1 -Tier <tier> -ServerOff "y"`
# and: `.\bundle_zip.ps1 -Tier <tier> -IsGHA "Y"` or: `.\bundle_zip.ps1 -Tier <tier> -IsGHA "y"`
#   Tier is required and has no default to avoid mistaken bundles.

# This script is also used with gh action runner with the -ServerOff switch set to yes and -IsGHA set to yes. Both `pnpm install` and 'node build.js` have already run in earlier steps in windows-build-steps.yml

[CmdletBinding()]
param(
    [string]$ServerOff,
    [string]$IsGHA,
    [string]$Tier
)

function Resolve-Tiered($entries, $label) {
  $m = @($entries | Where-Object { $_.branches -contains $Tier })
  if ($m.Count -ne 1) { throw "$label must have exactly one entry for tier '$Tier', found $($m.Count)" }
  $m[0].value
}

# Load app_config.json and resolve tier values -- before asking anything.
# Errors print as a single line (no stack trace) and exit 1.
try {
  $config = Get-Content -Path (Join-Path $PSScriptRoot "..\..\app_config.json") -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

  # Tier is required (-Tier). No default, no fallback. Checked here so a missing value fails with a clear error
  # instead of pausing for input as happens in ps1 if designated Mandatory.
  if (@($config.tiers.order) -notcontains $Tier) {
    throw "-Tier is required and must be one of: $(@($config.tiers.order) -join ', ') (got '$Tier')."
  }

  $APP_NAME    = [string](Resolve-Tiered $config.app.name 'app.name')
  $APP_VERSION = [string](Resolve-Tiered $config.app.version 'app.version')
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
  echo "     Exiting..."
  echo "`n"
  echo "     If the server is on, turn it off by exiting the terminal window in which it is running, then re-run this script.";
  echo "`n"
  exit 1
}

echo "`n"
echo "Continuing..."
echo "`n"

if ($IsGHA -ne 'Y') {
  cd ..\..\
  # echo "checkout main"
  # git checkout main | Out-Null
  # echo "pull"
  # git pull
  # echo "pnpm install"
  # pnpm install
  echo "`n"
  cd windows\scripts
}

echo "`n"
echo "Tier is $Tier"
echo "Version is $APP_VERSION"
echo "`n"

if ($IsGHA -ne 'Y') {
  cd ..\..\
  If (Test-Path releases\windows\*.zip) {
    echo "A previous windows .zip release exists. Removing..."
    Remove-Item releases\windows\*.zip
  }
  cd windows\scripts
  if (Test-Path ..\build) {
    echo "Removing last build environment"
    rm ..\build -r -force
  }
  echo "Assembling build environment"
  node build.js $Tier
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: node build.js failed for tier '$Tier' (exit code $LASTEXITCODE)"
    exit 1
  }
}

cd ..\build
echo "`n"
echo "   *****************************************************************************************"
echo "   *                                                                                       *"
echo "   *                                          =====                                        *"
echo "   * Bundling. Wait for the powershell prompt AFTER the compression progress bar finishes. *"
echo "   *                                          =====                                        *"
echo "   *                                                                                       *"
echo "   *****************************************************************************************"
echo "`n"

# Use lower case app name in filename and replace spaces with dashes (-), matching buildCommon.js
$FILE_APP_NAME = $APP_NAME.ToLower().Replace(" ","-")

$CPU_ARCH = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
  "arm64"
} else {
  "x64"
}

Compress-Archive * ..\..\releases\windows\$FILE_APP_NAME-$APP_VERSION-win-$CPU_ARCH-cli.zip

if ($IsGHA -ne 'Y') {
  cd ..\scripts
} else {
  cd ..\install
}

exit 0
