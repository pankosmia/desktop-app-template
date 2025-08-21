# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\build_viewer.ps1

$TEMP_DIR = "..\temp"
  if (Test-Path $TEMP_DIR) {
      Write-Host "Deleting previous viewer build..."
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

..\install\makeAllInstallsElectronite.ps1 -Dev "Y" -IsGHA "N"