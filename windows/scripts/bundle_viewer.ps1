# This script uses the APP_VERSION environment variable as defined in app_config.env

# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\bundle_viewer.ps1
# with the optional arguments of: .\bundle_viewer.ps1 -ServerOff "Y"
# or: .\bundle_viewer.ps1 -ServerOff "y"

param(
    [string]$ServerOff
)

if ($ServerOff -eq 'Y') {
  $answer = $ServerOff
} else {
  echo "`n"
  $answer = Read-Host "     Is the server off?[Y/N y/n]"
}

if ($answer -eq 'Y') {
    echo "`n"
    echo "Continuing..."
    echo "`n"

  get-content ..\..\app_config.env | foreach {
    $name, $value = $_.split('=')
    if ([string]::IsNullOrWhiteSpace($name) -or $name.Contains('#')) {
      # skip empty or comment line in ENV file
      return
    }
    Set-Variable -Name $name -Value $value
  }

  If (-Not (Test-Path ..\..\local_server\target\release\local_server.exe)) {
    echo "`n"
    echo "   ***************************************************************"
    echo "   * IMPORTANT: Build the local server, then re-run this script! *"
    echo "   ***************************************************************"
    echo "`n"
    exit
  }

  cd ..\..\
  echo "checkout main"
  git checkout main | Out-Null
  echo "pull"
  git pull
  echo "npm install"
  npm install
  echo "`n"
  echo "Running app_setup to ensure version number consistency between buildSpec.json and this build bundle:"
  cd windows\scripts
  .\app_setup.bat

  echo "`n"
  echo "Version is $APP_VERSION"
  echo "`n"

  $TEMP_DIR = "../temp"
    if (Test-Path $TEMP_DIR) {
        Write-Host "Deleting previous build..."
        Write-Host "`n"
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

  Write-Host "`n"
  Write-Host "`n"
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`"Getting Electron release`" downloads an approximately 120 MB file." -f cyan;
  Write-Host "Please wait patiently for the highlighted download process to complete..." -f cyan;
  Write-Host "*************************************************************************" -f cyan;
  Write-Host "`n"

  ../install/makeAllInstallsElectronite.ps1 -IsGHA "N"

} elseif ($answer -eq 'N') {
    echo "`n"
    echo "     Turn the server off by exiting the terminal window in which it is running, then re-run this script while the server is off."
    echo "`n"
} else {
    echo "`n"
    echo "     Invalid input. Please enter Y or N."
    .\bundle_viewer.ps1
}