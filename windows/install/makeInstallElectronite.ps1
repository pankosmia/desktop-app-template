<#
.SYNOPSIS
    Creates a Windows installer package for the application.

.DESCRIPTION
    This PowerShell script prepares and builds a Windows installer for the application using Inno Setup.
    It creates the necessary directory structure, copies required files, and compiles the installer.

.PREREQUISITES
    - Inno Setup 6 must be installed at "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    - app_config.json at the repo root must define app.name, app.short_name, app.version,
      and resources.rocket_config, resources.electron_icon, resources.app_icon for the selected tier.

.OUTPUTS
    Creates an installer at releases\windows\<appname>-<version>-win-<arch>.exe

.NOTES
    - Cleans up existing installers before building
    - Creates directory structure in .\windows\$pkgDir\project\payload\<app-name>
    - Copies necessary files including Electron, README, bin, and lib directories
    - Compiles the installer using Inno Setup
    - resources.* values in app_config.json are relative to /windows/<subdir> (e.g. /windows/scripts).
      This script lives in /windows/install (same depth), so they are resolved against $PSScriptRoot,
      never against the current directory (which changes during the script).

.PARAMETER arch
    Target architecture for the installer (e.g., x64, arm64, x86)

.PARAMETER Dev
    Specify -DevEnvRun "Y" when generating a development environment viewer.
    - Default is "N"
    - Unrelated to the "dev" tier.

.PARAMETER FullInstall
    Specify -FullInstall $true for installing Electronite too; -FullInstall $false for updating all but Electronite (e.g., a development environment viewer update)
    - Default is $true

.PARAMETER p
    Specify -p for Portable App

.PARAMETER Tier
    Required. Builds all of the given tier from app_config.json: dev, qa, or main.
    - Must be listed in tiers.order.
    - Default is tiers.default
#>

param(
    [string]$arch,
    [string]$DevEnvRun = "N",
    [bool]$FullInstall = $true,
    [switch]$p,
    [string]$Tier
)

# Read app_config.json (repo root)
$APP_CONFIG_FILE = Join-Path $PSScriptRoot "..\..\app_config.json"
$APP_CONFIG = Get-Content -Path $APP_CONFIG_FILE -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json

# Default for Tier is <tiers.default>
if (-not $PSBoundParameters.ContainsKey('Tier')) {
    $Tier = $APP_CONFIG.tiers.default
}

# Save the initial working directory
$initialLocation = Get-Location

# Returns the value of the single entry whose branches include the tier.
function Get-TierValue {
    param($Entries, [string]$Key, [string]$TierName)
    $match = @($Entries | Where-Object { $_.branches -contains $TierName })
    if ($match.Count -ne 1) {
        throw "$Key must have exactly one entry for tier '$TierName' in app_config.json (found $($match.Count))."
    }
    return $match[0].value
}

# Resource paths are relative to /windows/<subdir>; resolve against this script's dir (/windows/install).
# Join-Path does not resolve the path, so wildcards (e.g. favicon*.png) are preserved.
function Get-ResPath {
    param([string]$Key)
    $rel = Get-TierValue $APP_CONFIG.resources.$Key "resources.$Key" $Tier
    return Join-Path $PSScriptRoot $rel
}

try {
    try {
        # Tier is required (-Tier). No fallback. Checked here so a missing value fails with a clear error
        # instead of pausing for input as happens in ps1 if designated Mandatory.
        if (@($APP_CONFIG.tiers.order) -notcontains $Tier) {
            throw "-Tier is required and must be one of: $(@($APP_CONFIG.tiers.order) -join ', ') (got '$Tier')."
        }

        # arch is required (-arch). No fallback. Checked here so a missing value fails with a clear error
        # instead of pausing for input as happens in ps1 if designated Mandatory.
        if (-not $arch) {
            Write-Host "Error: arch is required: -arch:arm64 or -arch:x64"
            exit 1
        }

        # App values for the tier, from app_config.json only. Set as process env vars
        # (overwriting anything inherited) because makeInstallElectronite.iss reads
        # APP_NAME, APP_VERSION, APP_SHORT_NAME, FILE_APP_NAME, ARCH, and APP_ICON via GetEnv().

        $env:APP_NAME       = [string](Get-TierValue $APP_CONFIG.app.name       "app.name"       $Tier)
        $env:APP_SHORT_NAME = [string](Get-TierValue $APP_CONFIG.app.short_name "app.short_name" $Tier)
        $env:APP_VERSION    = [string](Get-TierValue $APP_CONFIG.app.version    "app.version"    $Tier)

        # Resources for the tier (absolute via $PSScriptRoot; safe across Set-Location)
        $rocketConfig    = Get-ResPath "rocket_config"
        $electronIconSrc = Get-ResPath "electron_icon"
        $appIconSrc      = Get-ResPath "app_icon"
        $env:APP_ICON    = $appIconSrc   # read by makeInstallElectronite.iss
    }
    catch {
        Write-Host "Error reading app_config.json: $_"
        exit 1
    }

    $eMsg = "is not set for tier '$Tier' in app_config.json."

    if (-not $env:APP_VERSION) {
        Write-Host "Error: app.version $eMsg"
        exit 1
    }

    if (-not $env:APP_NAME) {
        Write-Host "Error: app.name $eMsg"
        exit 1
    }

    # Always derived from app.name for the tier (read by makeInstallElectronite.iss via GetEnv).
    # Lower case, spaces -> dashes.
    $env:FILE_APP_NAME = $env:APP_NAME.ToLower().Replace(" ","-")
    Write-Host "FILE_APP_NAME=$env:FILE_APP_NAME"

    if (-not $env:APP_SHORT_NAME) {
        Write-Host "Error: app.short_name $eMsg"
        exit 1
    }

    Write-Host "Tier is $Tier"
    Write-Host "Version is $env:APP_VERSION"

    # Needed for local bundles. Not required in GHA but does no harm.
    if ($DevEnvRun -ne 'Y') {
        # Clean up any existing installers
        Remove-Item -Path "..\..\releases\windows\$($env:FILE_APP_NAME)-*-win-$arch.exe" -Force -ErrorAction SilentlyContinue
    }

    # Change to build directory  (cwd: /windows/install -> /windows/build)
    Set-Location -Path "..\build" -ErrorAction Stop

    # Create folder structure for package
    if ($FullInstall) {
      Write-Host "Building folder structure for package..."
    }

    if ($DevEnvRun -eq 'Y') {
      $pkgDir = "viewer"
    } else {
        $pkgDir = "temp"
    }

    # Clean up and create project directories -- Needed for local bundles; Not required in GHA but also doesn't hurt anything.

    # Use full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText()  
    $projectPath = Join-Path (Get-Location).Path "..\$pkgDir\project" 
    $payloadPath = Join-Path $projectPath "payload\app"

    if ($FullInstall -or $DevEnvRun -ne 'Y') {
        Remove-Item -Path $projectPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Force -Path $payloadPath | Out-Null

    # Copy Rocket.toml (resources.rocket_config) and devAppLauncherElectron.bat
    $startupSrc = "..\buildResources\devAppLauncherElectron.bat"
    $startupDest = "$payloadPath"
    if (Test-Path $startupSrc) {
        New-Item -ItemType Directory -Force -Path $startupDest | Out-Null
        Copy-Item -Path $rocketConfig -Destination "$startupDest\Rocket.toml" -Force
        Copy-Item -Path $startupSrc -Destination "$startupDest\devAppLauncherElectron.bat" -Force
    }

    # Copy electron files
    if ($FullInstall) {
      Write-Host "Preparing Electron files..."
    } else {
      Write-Host "Preparing viewer update..."
    }
    try {
        $electronSrcPath = Join-Path $PSScriptRoot "..\..\buildResources\electron\*"
        $electronDestPath = Join-Path $payloadPath "electron"

        if ($FullInstall) {
          Write-Host "Electron source path: $electronSrcPath" -ErrorAction SilentlyContinue
          Write-Host "Electron destination path: $electronDestPath" -ErrorAction SilentlyContinue
        }

        # Ensure destination parent exists
        $destParent = Split-Path -Parent $electronDestPath
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }

        # Ensure source exists
        if (-not (Test-Path $electronSrcPath)) {
            Write-Error "Source path not found: $electronSrcPath"
            exit 1
        }

        # Explicitly create electron destination directory if not found 
        if (-not (Test-Path $electronDestPath)) {
            New-Item -ItemType Directory -Path $electronDestPath -Force | Out-Null
        }

        # Copy all app-specific electron files
        Copy-Item -Path $electronSrcPath -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
        Write-Host "Successfully copied app-specific electron files"
        if (-not (Test-Path $electronDestPath)) {
            Write-Error "Electron destination path not found for app-specific files: $electronDestPath"
            exit 1
        }

        # Copy main electron browser window icon (resources.electron_icon)
        Write-Host "Copying $(Split-Path -Leaf $electronIconSrc) to $electronDestPath ..."
        Copy-Item $electronIconSrc -Destination $electronDestPath -Force

        # Copy required modules and dependencies
        $nodeModulesSrc = Join-Path $PSScriptRoot "..\..\node_modules"
        $nodeModulesDest = Join-Path $electronDestPath "node_modules"

        # Explicitly create node_modules if not found
        if (-not (Test-Path $nodeModulesDest)) {
            New-Item -ItemType Directory -Path $nodeModulesDest -Force | Out-Null
        }

        # 7zip-min (full directory) -- Windows only
        $7zipMinDest = Join-Path $nodeModulesDest "7zip-min"
        New-Item -ItemType Directory -Path $7zipMinDest -Force | Out-Null
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-min\*") -Destination $7zipMinDest -Recurse -Force -ErrorAction Stop

        # 7zip-bin (selective: index.js, package.json, and arch-specific binary) -- Windows only
        $7zipBinDest = Join-Path $nodeModulesDest "7zip-bin"
        $7zipBinWinArchDest = Join-Path $7zipBinDest "win\$arch"
        New-Item -ItemType Directory -Path $7zipBinWinArchDest -Force | Out-Null
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\index.js") -Destination $7zipBinDest -Force -ErrorAction Stop
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\package.json") -Destination $7zipBinDest -Force -ErrorAction Stop
        Copy-Item -Path (Join-Path $nodeModulesSrc "7zip-bin\win\$arch\*") -Destination $7zipBinWinArchDest -Recurse -Force -ErrorAction Stop

        # Copy required modules and dependencies -- all OSes
        $allOsModules = @(
            "puppeteer-core",
            "@puppeteer\browsers",
            "chromium-bidi",
            "debug",
            "devtools-protocol",
            "ms",
            "typed-query-selector",
            "webdriver-bidi-protocol",
            "ws",
            "semver",
            "proxy-agent",
            "lru-cache",
            "agent-base",
            "proxy-from-env",
            "progress",
            "mitt"
        )

        foreach ($mod in $allOsModules) {
            $modDest = Join-Path $nodeModulesDest $mod
            New-Item -ItemType Directory -Path $modDest -Force | Out-Null
            Copy-Item -Path (Join-Path $nodeModulesSrc "$mod\*") -Destination $modDest -Recurse -Force -ErrorAction Stop
        }

        Write-Host "Successfully copied node_modules dependencies"

        # $electronDestPath is full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText() 

        # Replace all occurrences of ${APP_NAME} and ${APP_VERSION} in startup script
        $esPath = "$electronDestPath\electronStartup.js"
        $esText = [System.IO.File]::ReadAllText($esPath).Replace('${APP_NAME}', $env:APP_NAME)
        [System.IO.File]::WriteAllText($esPath, $esText, [System.Text.UTF8Encoding]::new($false))

        $pkgPath = "$electronDestPath\package.json"
        $pkgText = [System.IO.File]::ReadAllText($pkgPath).Replace('${APP_NAME}', $env:APP_NAME).Replace('${APP_VERSION}', $env:APP_VERSION)
        [System.IO.File]::WriteAllText($pkgPath, $pkgText, [System.Text.UTF8Encoding]::new($false))
        
        if ($FullInstall) {
            # Copy architecture-specific files
            $archElectronPath = Join-Path $PSScriptRoot "..\$pkgDir\electron.$arch"
            Write-Host "Electron arch path: $archElectronPath" -ErrorAction SilentlyContinue

            if (Test-Path $archElectronPath) {
                Copy-Item -Path "$archElectronPath\*" -Destination $electronDestPath -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully copied architecture-specific files"
            } else {
                Write-Warning "Architecture-specific path not found: $archElectronPath"
            }
        } else {
            Write-Host "Skipping architecture-specific electron file copy (not needed)."
        }
    }
    catch {
        Write-Error "Failed to prepare electron files: $_"
        exit 1
    }

    if ($DevEnvRun -ne 'Y') {
        # Copy README
        $readmeSrc = "..\build\README.txt"
        $readmeDest = "$payloadPath"
        if (Test-Path $readmeSrc) {
            New-Item -ItemType Directory -Force -Path $readmeDest | Out-Null
            Copy-Item -Path $readmeSrc -Destination "$readmeDest\README.txt" -Force
        }

        # Copy bin and lib directories from build directory
        if (Test-Path ".\bin") {
            Copy-Item -Path ".\bin" -Destination $payloadPath -Recurse -Force
        }
        if (Test-Path ".\lib") {
            Copy-Item -Path ".\lib" -Destination $payloadPath -Recurse -Force
        }

        # Create and copy scripts if needed
        $scriptsPath = "$projectPath\scripts"
        New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

        # Map internal arch token to output naming
        $env:ARCH = $arch

        # cwd: /windows/build -> /windows
        Set-Location -Path ".."
        $outputPath = "..\releases\windows"

        New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

        $packageBaseName = "$($env:FILE_APP_NAME)-$($env:APP_VERSION)-win-$arch"

        if ($p.IsPresent) {
            Write-Host "Building portable ZIP..."

            # These are the same sources used by install\makeInstallElectronite.iss.
            $payloadSource = ".\temp\project\payload\app"
            $iconSource = $appIconSrc   # resources.app_icon

            # Stage the portable app under a top-level folder named after the app.
            # Use full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText()
            $portableStage = Join-Path (Get-Location).Path 'temp\project\portable-package'
            $portableAppDirName = $env:APP_NAME
            $portableAppStage = Join-Path $portableStage $portableAppDirName
            $portableZipPath = Join-Path $outputPath "$packageBaseName-portable.zip"

            if (-not (Test-Path $payloadSource)) {
                Write-Error "Portable payload directory not found: $payloadSource"
                exit 1
            }

            if (-not (Test-Path $iconSource)) {
                Write-Error "Portable icon not found: $iconSource"
                exit 1
            }

            Remove-Item -Path $portableStage -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $portableAppStage -Force | Out-Null

            # Equivalent to:
            # Source: "..\temp\project\payload\app\*"; DestDir: "{app}"
            Copy-Item `
                -Path (Join-Path $payloadSource "*") `
                -Destination $portableAppStage `
                -Recurse `
                -Force `
                -ErrorAction Stop

            # Equivalent to:
            # Source: "<resources.app_icon>"; DestDir: "{app}"
            Copy-Item `
                -Path $iconSource `
                -Destination (Join-Path $portableAppStage "icon.ico") `
                -Force `
                -ErrorAction Stop

            # Portable app uses a virtual path for repo_dir.
            # Staged copy only -- never $payloadPath, which Inno Setup packages into the EXE.
            # $portableAppStage is full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText()
            $user_settings = Join-Path $portableAppStage "lib\templates\user_settings.json"
            if (-not (Test-Path $user_settings)) {
                Write-Error "Portable user_settings.json not found: $user_settings"
                exit 1
            }
            $usText = [System.IO.File]::ReadAllText($user_settings).Replace('"repo_dir": "%%HOMEDIR%%/pankosmia_repos",', '"repo_dir": "..\pankosmia_repos",')
            [System.IO.File]::WriteAllText($user_settings, $usText, [System.Text.UTF8Encoding]::new($false))
            
            # Copy configured helper files to the ZIP root.
            $helpersSource = ".\buildResourcesPortable"
            $startAppBatDestination = Join-Path $portableStage "start.bat"
            $readMeDestination = Join-Path $portableStage "README.txt"

            $helperFiles = @(
                "start.bat",
                "README.txt"
            )

            foreach ($fileName in $helperFiles) {
                $source = Join-Path $helpersSource $fileName

                $destinationFileName = switch ($fileName) {
                    default         { $fileName }
                }

                $destination = Join-Path $portableStage $destinationFileName

                if (-not (Test-Path $source)) {
                    Write-Error "Portable helper files not found: $source"
                    exit 1
                }

                Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop

                # Replace placeholders only in the staged ZIP copy.
                $content = Get-Content -Path $destination -Raw
                $content = $content.Replace('%%APP_NAME%%', $env:APP_NAME)
                $content = $content.Replace('%%APP_SHORT_NAME%%', $env:APP_SHORT_NAME)
                $content = $content.Replace('%%ARCH%%', $env:ARCH)

                Set-Content -Path $destination -Value $content -NoNewline
            }

            # Remove the win desktop app readme that is not applicable to the portable app.
            $readmeToDel = Join-Path $portableAppStage "README.txt"
            Remove-Item -Path $readmeToDel -Force -ErrorAction SilentlyContinue

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
                    exit 1
                }
                if (-not $norm.Contains($Find)) {
                    Write-Host "Expected original text was not found in $Path ; no change made."
                    exit 1
                }

                $updated = $norm.Replace($Find, $Replace)
                [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
            }

            # $portableStage is full path b/c working dir diff between PS and .NET/process, e.g. ReadAllText() 

            # $serverFile  = Join-Path $electronDestPath 'core\server.js'
            $serverFile = Join-Path $portableStage "$env:APP_NAME\electron\core\server.js"
            
            # $startupFile = Join-Path $electronDestPath 'electronStartup.js'
            $startupFile = Join-Path $portableStage "$env:APP_NAME\electron\electronStartup.js"

            # --- server.js ---
            $serverFind    = 'spawn(SERVER_EXECUTABLE_PATH, []'
            $serverReplace = "spawn(SERVER_EXECUTABLE_PATH, [`'../pankosmia/$env:APP_SHORT_NAME`']"
            Update-FileText -Path $serverFile -Find $serverFind -Replace $serverReplace

            # --- electronStartup.js ---
            $startupFind    = "if (START_SERVER) {`n  app.setName('$env:APP_NAME');`n} else {"
            $startupReplace = "if (START_SERVER) {`n  app.setName('$env:APP_NAME');`n  app.setPath('userData', path.resolve(process.cwd(), './pankosmia/AppData', '$env:APP_SHORT_NAME'));`n} else {"
            Update-FileText -Path $startupFile -Find $startupFind -Replace $startupReplace

            Remove-Item -Path $portableZipPath -Force -ErrorAction SilentlyContinue

            # Archive a single top-level directory named after the application.
            Compress-Archive `
                -Path $portableAppStage, $startAppBatDestination, $readMeDestination `
                -DestinationPath $portableZipPath `
                -CompressionLevel Optimal `
                -Force

            if (-not (Test-Path $portableZipPath)) {
                Write-Error "Portable ZIP was not created: $portableZipPath"
                exit 1
            }

            Write-Host "Portable package created successfully: $portableZipPath"
        }

        # Remove the CLI find_free_port.bat script that is not applicable to the EXE where that is handled by Electron.
        $findPortScriptToDel = Join-Path $payloadPath "find_free_port.bat"
        Remove-Item -Path $findPortScriptToDel -Force -ErrorAction SilentlyContinue

        # Delete existing exe files from releases directory, only if path exists
        Get-ChildItem -Path $outputPath -Filter "*.exe" -ErrorAction SilentlyContinue |
            Remove-Item -Force

        # Call Inno Setup to create installer
        Write-Host "Building installer..."

        $innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        if (-not (Test-Path $innoSetupPath)) {
            Write-Host "Error: Inno Setup not found at $innoSetupPath"
            exit 1
        }

        $setupScript = ".\install\makeInstallElectronite.iss"

        Write-Host "Current working directory: $(Get-Location)"

        $process = Start-Process `
            -FilePath $innoSetupPath `
            -ArgumentList "/O`"$outputPath`"", $setupScript `
            -NoNewWindow `
            -Wait `
            -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Host "Error: Inno Setup compilation failed"
            exit 1
        }

        Write-Host "Installation package created successfully"
        exit 0
    }

    # Development environment viewer run (-DevEnvRun "Y") ends here. Exit explicitly so the
    # caller's $LASTEXITCODE check doesn't see a stale value from an earlier command.
    exit 0
}

finally {
    # Restore the original working directory
    Set-Location -Path $initialLocation
}

