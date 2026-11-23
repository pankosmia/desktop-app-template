# Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\build_viewer.ps1
# Or force a full install with: .\build_viewer.ps1 -f
# Or build a different tier with: .\build_viewer.ps1 -Tier qa   (or main)
#   -Tier defaults to dev (most common for local viewer builds); must be listed in tiers.order in app_config.json.
#   Builds the local development environment viewer (-DevEnvRun "Y"); the -Tier default is a separate choice.

param(
    [string]$Tier = "dev",
    [switch]$f
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

# All relative paths below (and in makeAllInstallsElectronite.ps1) assume windows\scripts.
Push-Location $PSScriptRoot

try {
    # Read app_config.json (repo root)
    try {
        $configFile = Join-Path $PSScriptRoot "..\..\app_config.json"
        $config = Get-Content -Path $configFile -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

        # Tier is required (-Tier). No fallback. Checked here so a missing value fails with a clear error
        # instead of pausing for input as happens in ps1 if designated Mandatory.
        if (@($config.tiers.order) -notcontains $Tier) {
            throw "-Tier is required and must be one of: $(@($config.tiers.order) -join ', ') (got '$Tier')."
        }

        # Expected Electronite version, derived from electronite.url for this machine's arch
        $CPU_ARCH = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) { "arm64" } else { "x64" }
        $electronUrls = Get-TierValue $config.electronite.url "electronite.url" $Tier
        $electronUrl = $electronUrls."win32-$CPU_ARCH"
        if (-not $electronUrl) {
            throw "electronite.url has no 'win32-$CPU_ARCH' entry for tier '$Tier'."
        }
        if ($electronUrl -notmatch 'electronite-v(\d+\.\d+\.\d+)') {
            throw "Could not determine Electronite version from electronite.url: $electronUrl"
        }
        $expected = $Matches[1]
    }
    catch {
        Write-Host "Error reading app_config.json: $_"
        exit 1
    }

    Write-Host "Tier is $Tier"
    Write-Host "Expected Electronite version is $expected"

    $ELECTRON_VER = "..\viewer\project\payload\app\electron\version"

    $installElectron = $f.IsPresent

    if (-not $installElectron) {
        if (Test-Path -LiteralPath $ELECTRON_VER -PathType Leaf) {
            $content = (Get-Content -LiteralPath $ELECTRON_VER -Raw).Trim()
            if ($content -eq $expected) {
                Write-Host "The installed viewer Electronite version is $content, which is correct."
                Write-Host 'No download is needed. Everything else will be updated.'
                $installElectron = $false
            } else {
                Write-Host "The installed viewer Electronite version is $content, however we are now using $expected. Please wait for the download and upgrade that will follow..."
                $installElectron = $true
            }
        }
        else {
            Write-Host 'A full viewer install will follow, including download of Electronite. Please wait patiently...'
            $installElectron = $true
        }
    } else {
        Write-Host '-f flag detected.'
        Write-Host 'A full viewer install will follow, including download of Electronite. Please wait patiently...'
    }

    $TEMP_DIR = "..\viewer"
    if ($installElectron -and (Test-Path $TEMP_DIR)) {
        Write-Host "Deleting previous viewer build..."
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }

    if ($installElectron) {
        Write-Host "*************************************************************************" -f cyan;
        Write-Host "`"Getting Electron release`" downloads an approximately 120 MB file." -f cyan;
        Write-Host "Please wait patiently for the highlighted download process to complete..." -f cyan;
        Write-Host "*************************************************************************" -f cyan;
    }

    & (Join-Path $PSScriptRoot "..\install\makeAllInstallsElectronite.ps1") -Tier $Tier -DevEnvRun "Y" -IsGHA "N" -FullInstall:$installElectron

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: makeAllInstallsElectronite.ps1 failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
