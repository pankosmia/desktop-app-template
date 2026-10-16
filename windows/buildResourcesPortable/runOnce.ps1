<#
✓  (repo_location is already preset to virtual)
First start the portable app server with  electron core\server.js as serverProcess = spawn(SERVER_EXECUTABLE_PATH, [], {  (same as installed apps).
Then close the app.
Then run this script.
Then start that app again, and the portable app will be running.
#>

$marker = Join-Path $PSScriptRoot 'script_has_run.flag'

if (Test-Path $marker) {
    Write-Host 'This script has already been run.'
    exit 1
}

try {
    # ---- One-time work goes here ----
    Write-Host 'Running one-time portable app setup...'

    # Move working directory from home (~) to portable app
    $workingSource = Join-Path $HOME "pankosmia\%%APP_SHORT_NAME%%"
    if (Test-Path -LiteralPath $workingSource) {
        Move-Item -LiteralPath $workingSource -Destination "." -Force
    }

    # Remove Electron AppData directory that will be recreated in a new location for the portable app
    $dir = Join-Path $env:APPDATA "%%APP_NAME%%"
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
    }

    $electronDestPath = Join-Path "%%APP_NAME%%" "electron"

    # Portable App - Specify working dir virtual path using replace.
    (Get-Content "$electronDestPath\core\server.js").Replace("spawn(SERVER_EXECUTABLE_PATH, []", "spawn(SERVER_EXECUTABLE_PATH, ['../pankosmia/%%APP_SHORT_NAME%%']") | Set-Content "$electronDestPath\core\server.js"
    
    # Portable App - Specify virtual electron data path using replace.
    $findText = "if (START_SERVER) {$([Environment]::NewLine)  app.setName('%%APP_NAME%%::NewLine)} else {"
    $replaceText = "if (START_SERVER) {$([Environment]::NewLine)  app.setName('%%APP_NAME%%');$([Environment]::NewLine)  app.setPath('userData', path.resolve(process.cwd(), '../pankosmia/$env:APP_SHORT_NAME', 'AppData'));$([Environment]::NewLine)} else {"
    (Get-Content -Raw "$electronDestPath\electronStartup.js").Replace($findText, $replaceText) | Set-Content "$electronDestPath\electronStartup.js"

    # Create marker only after successful completion
    New-Item -Path $marker -ItemType File -Force | Out-Null

    Write-Host 'Done. This script will not run again.'
}
catch {
    Write-Error "Setup failed: $_"
    exit 1
}


