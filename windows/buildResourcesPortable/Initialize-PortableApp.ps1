<#
✓  (repo_location is already preset to virtual)
First start the portable app server with  electron core\server.js as serverProcess = spawn(SERVER_EXECUTABLE_PATH, [], {  (same as installed apps).
Then close the app.
Then run this script.
Then start that app again, and the portable app will be running.
#>

$root = $PSScriptRoot

function Update-FileText {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Find,     # uses `n newlines
        [Parameter(Mandatory)] [string] $Replace   # uses `n newlines
    )

    $raw  = [System.IO.File]::ReadAllText($Path)
    $norm = $raw -replace "`r`n", "`n" -replace "`r", "`n"

    if ($norm.Contains($Replace)) {
        Write-Host "$Path was not updated by this run; '$Replace' already present."
        return $true    # end-state satisfied (case 2)
    }
    if (-not $norm.Contains($Find)) {
        Write-Host "Expected original text was not found in $Path ; no change made."
        return $false   # case 3 — blocks deletion
    }

    $updated = $norm.Replace($Find, $Replace)
    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
    return $true        # end-state satisfied (case 1)
}

try {
    Write-Host 'Running one-time portable app setup...'

    # Move working directory from home (~) to portable app
    $workingSource = Join-Path $HOME "pankosmia\%%APP_SHORT_NAME%%"
    $destination   = Join-Path $root  "pankosmia\%%APP_SHORT_NAME%%"

    if ((Test-Path -LiteralPath $workingSource) -and -not (Test-Path -LiteralPath $destination)) {
        $destParent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        Move-Item -LiteralPath $workingSource -Destination $destination
    }
    else {
        if (Test-Path -LiteralPath $destination) {
            Write-Host "$destination already exists."
        }
        if (-not (Test-Path -LiteralPath $workingSource)) {
            Write-Host "$workingSource does not exist."
        }
        Write-Host "$workingSource was not moved to: $destination"
    }

    # Remove old Roaming AppData
    $dir = Join-Path $env:APPDATA "%%APP_NAME%%"
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
    }
    else {
        Write-Host "$dir does not exist, thus was not removed."
    }

    $electronDestPath = Join-Path (Join-Path $root "%%APP_NAME%%") "electron"
    $serverFile  = Join-Path $electronDestPath 'core\server.js'
    $startupFile = Join-Path $electronDestPath 'electronStartup.js'

    # --- server.js ---
    $serverFind    = 'spawn(SERVER_EXECUTABLE_PATH, []'
    $serverReplace = "spawn(SERVER_EXECUTABLE_PATH, [`'../pankosmia/%%APP_SHORT_NAME%%`']"
    $okServer = Update-FileText -Path $serverFile -Find $serverFind -Replace $serverReplace

    # --- electronStartup.js ---
    $startupFind    = "if (START_SERVER) {`n  app.setName('%%APP_NAME%%');`n} else {"
    $startupReplace = "if (START_SERVER) {`n  app.setName('%%APP_NAME%%');`n  app.setPath('userData', path.resolve(process.cwd(), '../pankosmia/%%APP_SHORT_NAME%%', 'AppData'));`n} else {"
    $okStartup = Update-FileText -Path $startupFile -Find $startupFind -Replace $startupReplace

    # ---- Gate: delete only if all four end-states hold ----
    $okDestination = Test-Path -LiteralPath $destination
    $okRoamingGone = -not (Test-Path -LiteralPath $dir)

    if ($okDestination -and $okRoamingGone -and $okServer -and $okStartup) {
        Write-Host 'Done. All conditions satisfied; removing setup script.'
        Remove-Item -LiteralPath $PSCommandPath -Force
    }
    else {
        Write-Host ''
        Write-Host 'Setup did NOT fully complete. Script left in place for review/re-run.'
        Write-Host "  destination exists : $okDestination"
        Write-Host "  roaming AppData gone: $okRoamingGone"
        Write-Host "  server.js updated   : $okServer"
        Write-Host "  startup updated     : $okStartup"
        cmd /c pause
    }
}
catch {
    Write-Host ''
    Write-Error "Setup failed: $_"
    cmd /c pause
    exit 1
}
