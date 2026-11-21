# This script uses app.name and app.version from app_config.json for the selected tier.

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_zip.ps1
# with the optional arguments of: `.\bundle_zip.ps1 -ServerOff "Y"` or: `.\bundle_zip.ps1 -ServerOff "y"`
# and: `.\bundle_zip.ps1 -IsGHA "Y"` or: `.\bundle_zip.ps1 -IsGHA "y"`
# and: `.\bundle_zip.ps1 -Tier dev|qa|main`
#   Tier defaults to APP_TIER, then BRANCHES, then tiers.default in app_config.json.

# This script is also used with gh action runner with the -ServerOff switch set to yes and -IsGHA set to yes. Both `pnpm install` and 'node build.js` have already run in earlier steps in windows-build-steps.yml

param(
    [string]$ServerOff,
    [string]$IsGHA,
    [string]$Tier
)

if ($ServerOff -eq 'Y') {
  $answer = $ServerOff
} else {
  echo "`n"
  $answer = Read-Host "     Is the server off? [Y/n]: "
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

  function Resolve-Tiered($entries, $label) {
    $m = @($entries | Where-Object { $_.branches -contains $Tier })
    if ($m.Count -ne 1) { throw "$label must have exactly one entry for tier '$Tier', found $($m.Count)" }
    $m[0].value
  }

  $APP_NAME    = Resolve-Tiered $cfg.app.name 'app.name'
  $APP_VERSION = Resolve-Tiered $cfg.app.version 'app.version'

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
    if ($LASTEXITCODE -ne 0) { throw "node build.js failed for tier '$Tier'" }
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

} elseif ($answer -eq 'N') {
    echo "`n"
    echo "     Exiting..."
    echo "`n"
    echo "     If the server is on, turn it off by exiting the terminal window in which it is running, then re-run this script.";
    echo "`n"
} else {
    echo "`n"
    echo """$answer"" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit."
    .\bundle_zip.ps1 -IsGHA $IsGHA -Tier $Tier
}
