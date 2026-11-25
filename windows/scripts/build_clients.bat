@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in PowerShell or cmd by:  .\build_clients.bat

REM Usage:
REM   .\build_clients.bat [branch] [fallback_tier] [-d] [-f]
REM     The -d argument means to delete past logs without asking
REM     The -f argument means only fresh clones are being built, so pulling is skipped.
REM     The first non-flag argument is the branch name (default: tiers.default in app_config.json, i.e. dev)
REM     The second non-flag argument is the tier from tiers.order -- e.g., dev, qa, or main
REM       (default: the branch itself if it is a tier name, otherwise tiers.default)
REM     The tier selects which assets/clients are built, and the checkout fallback chain.

REM Examples where tiers.order is ["dev", "qa", "main"] and tiers.default is dev
REM   .\build_clients.bat                        # dev  -> tries dev -> qa -> main
REM   .\build_clients.bat qa                     # tries qa -> main
REM   .\build_clients.bat main                   # tries main
REM   .\build_clients.bat my-branch              # tries my-branch -> dev -> qa -> main
REM   .\build_clients.bat my-branch qa -d        # tries my-branch -> qa -> main, deletes past logs
REM   .\build_clients.bat -f -d dev              # fresh clones (skips pulling), delete logs, dev -> qa -> main

set "SCRIPT_DIR=%~dp0"
set "APP_CONFIG=%SCRIPT_DIR%..\..\app_config.json"
set "deleteLogs="
set "BRANCH="
set "FALLBACK_TIER="
set "FRESH_CLONE="

REM Temporary until migration from npm to pnpm is complete on main
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
  set npm_config_dangerouslyAllowAllBuilds=true
  set npm_config_dangerously_allow_all_builds=true
)

:loop
if "%~1"=="" goto :continue
if /I "%~1"=="-d" (
  set "deleteLogs=-d"
  shift
  goto :loop
)
if /I "%~1"=="-f" (
  set "FRESH_CLONE=1"
  shift
  goto :loop
)
REM First non-flag argument is the branch
if not defined BRANCH (
  set "BRANCH=%~1"
  shift
  goto :loop
)
REM Second non-flag argument is the tier
if not defined FALLBACK_TIER (
  set "FALLBACK_TIER=%~1"
  shift
  goto :loop
)
shift
goto :loop

:continue

if not exist "%APP_CONFIG%" (
  echo app_config.json not found at "%APP_CONFIG%"
  exit /b 1
)
where jq >nul 2>&1
if errorlevel 1 (
  echo jq was not found on PATH.
  exit /b 1
)

REM Default tier from app_config.json
for /f "usebackq delims=" %%T in (`jq -r ".tiers.default" "%APP_CONFIG%"`) do set "DEFAULT_TIER=%%T"

REM Assign default values
if not defined BRANCH set "BRANCH=%DEFAULT_TIER%"

REM If no tier specified, use the branch if it is a tier name, otherwise the default tier
if not defined FALLBACK_TIER (
  jq -e --arg t "%BRANCH%" ".tiers.order | index($t)" "%APP_CONFIG%" >nul 2>&1
  if errorlevel 1 (
    set "FALLBACK_TIER=%DEFAULT_TIER%"
  ) else (
    set "FALLBACK_TIER=%BRANCH%"
  )
)

REM Validate the tier
for /f "usebackq delims=" %%T in (`jq -r ".tiers.order[]" "%APP_CONFIG%"`) do call set "tiers=%%tiers%% %%T"
jq -e --arg t "%FALLBACK_TIER%" ".tiers.order | index($t)" "%APP_CONFIG%" >nul 2>&1
if errorlevel 1 (
  echo Unknown tier "%FALLBACK_TIER%". <tiers.default> must be one of:%tiers%.
  exit /b 1
)

REM ---- past logs ----
if not exist "%SCRIPT_DIR%build_clients_*.log" goto :moving_on
echo.
if /I "%deleteLogs%"=="-d" goto :delete_logs
:choice
set "c="
set /P "c=Delete past logs? [Y/n]: "
if "%c%"=="" goto :delete_logs
if /I "%c%"=="Y" goto :delete_logs
if /I "%c%"=="N" goto :moving_on
echo "%c%" is not a valid response. Type y or 'Enter' to delete past logs or 'n' to keep them.
goto :choice
:delete_logs
del /q "%SCRIPT_DIR%build_clients_*.log"
:moving_on

setlocal ENABLEDELAYEDEXPANSION

REM Fallback chain: the tier and every tier after it in tiers.order (e.g. dev -> dev qa main)
set "CHAIN="
for /f "usebackq delims=" %%B in (`jq -r --arg t "%FALLBACK_TIER%" ".tiers.order as $o | $o[($o | index($t)):][]" "%APP_CONFIG%"`) do set "CHAIN=!CHAIN! %%B"

REM ---- logging + failure tracking ----
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "LOG=%SCRIPT_DIR%build_clients_%TS%.log"
> "%LOG%" echo ===== Build started %DATE% %TIME% =====
set /a FAILCOUNT=0
set /a SKIPCOUNT=0
set /a ASSET_N=0
set /a CLIENT_N=0

REM Create a PowerShell helper script (used for tee-ing output)
set "PSRUNNER=%TEMP%\bat_tee_run.ps1"
del "%PSRUNNER%" 2>nul
>  "%PSRUNNER%" echo $LogPath = $args[0]
>> "%PSRUNNER%" echo $cmdLine = ($args ^| Select-Object -Skip 1^) -join ' '
>> "%PSRUNNER%" echo $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
>> "%PSRUNNER%" echo $sw = New-Object System.IO.StreamWriter($LogPath,$true,$utf8NoBom)
>> "%PSRUNNER%" echo try {
>> "%PSRUNNER%" echo   cmd.exe /d /s /c ^"$cmdLine 2^>^&1^" ^| ForEach-Object {
>> "%PSRUNNER%" echo     $_
>> "%PSRUNNER%" echo     $clean = [regex]::Replace($_, '\x1B\[[0-?]*[ -/]*[@-~]', '')
>> "%PSRUNNER%" echo     $sw.WriteLine($clean)
>> "%PSRUNNER%" echo   }
>> "%PSRUNNER%" echo } finally { $sw.Dispose() }
>> "%PSRUNNER%" echo exit $LASTEXITCODE
REM -----------------------------------

call :log Branch: %BRANCH%   Tier: %FALLBACK_TIER%   Fallback chain:%CHAIN%
call :log

REM Work from the parent of this repo, where assets and clients are cloned
cd /d "%SCRIPT_DIR%..\..\.."

for /f "usebackq delims=" %%R in (`jq -r --arg t "%FALLBACK_TIER%" ".assets[] | select(.branches | index($t)) | .repo" "%APP_CONFIG%"`) do call :do_asset %%R
for /f "usebackq delims=" %%R in (`jq -r --arg t "%FALLBACK_TIER%" ".clients[] | select(.branches | index($t)) | .repo" "%APP_CONFIG%"`) do call :do_client %%R

cd /d "%SCRIPT_DIR%"

REM ---- concise summary ----
echo.
echo ================================= SUMMARY =================================
echo Branch: %BRANCH%   Tier: %FALLBACK_TIER%
if %FAILCOUNT% EQU 0 (
  echo All builds succeeded.
) else (
  echo Failed steps: %FAILCOUNT%
  for /l %%i in (1,1,%FAILCOUNT%) do echo   !FAIL%%i!
)
if %SKIPCOUNT% GTR 0 (
  echo.
  echo Skipped pulls: %SKIPCOUNT%
  for /l %%i in (1,1,%SKIPCOUNT%) do echo   !SKIP%%i!
)
echo.
if /i "%GITHUB_ACTIONS%"=="true" (
  echo Full log: scroll up in the "Run build_clients.bat" step output above.
) else (
  for %%F in ("%LOG%") do echo Full log: "%%~nxF" in the current directory.
)
echo ===========================================================================

set "EXITCODE=0"
if %FAILCOUNT% GTR 0 set "EXITCODE=1"

endlocal & exit /b %EXITCODE%


:do_asset
REM %~1 = asset repo name
set /a ASSET_N+=1
set "REPO=%~1"
call :log ############################### BEGIN Asset !ASSET_N!: %REPO% ###############################
if not exist "%REPO%" (
  call :log
  call :log ****************************************************
  call :log %REPO% does not exist; Run .\clone.bat
  call :log ****************************************************
  call :log
  call :markfail "ASSET" "%REPO%" "directory not found; run .\clone.bat"
  exit /b 0
)
cd "%REPO%"
call :checkout_branch "ASSET" "%REPO%"
call :safe_pull "ASSET" "%REPO%"
call :log ################################ END Asset !ASSET_N!: %REPO% ################################
call :log
cd ..
exit /b 0


:do_client
REM %~1 = client repo name
set /a CLIENT_N+=1
set "REPO=%~1"
call :log ############################### BEGIN Client !CLIENT_N!: %REPO% ###############################
if not exist "%REPO%" (
  call :log
  call :log ***************************************************************************************
  call :log %REPO% does not exist; Run .\clone.bat then rerun .\build_clients.bat
  call :log ***************************************************************************************
  call :log
  call :markfail "CLIENT" "%REPO%" "directory not found; run .\clone.bat"
  exit /b 0
)
cd "%REPO%"
call :checkout_branch "CLIENT" "%REPO%"
call :safe_pull "CLIENT" "%REPO%"

if /I "!CHECKED_OUT_BRANCH!"=="main" (
  REM Temporary until migration from npm to pnpm is complete on main
  set CI=true
  set npm_config_dangerously_allow_all_builds=true

  call :log -- pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile ...
  call :run pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile
  if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm --config.dangerouslyAllowAllBuilds=true install --no-frozen-lockfile"

  if /I "%REPO%"=="core-client-dashboard" (
    call :log -- temporarily adding @mui/icons-material...
    call :run pnpm add @mui/icons-material@6.5.0
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add @mui/icons-material@6.5.0"
  ) else if /I "%REPO%"=="core-client-i18n-editor" (
    call :log -- temporarily adding notistack...
    call :run pnpm add notistack
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add notistack"
  ) else if /I "%REPO%"=="core-client-settings" (
    call :log -- temporarily adding notistack...
    call :run pnpm add notistack
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add notistack"
  ) else if /I "%REPO%"=="core-contenthandler_t_core" (
    call :log -- temporarily adding notistack, and prop-types needed by main...
    call :run pnpm add notistack
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add notistack"
    call :run pnpm add prop-types
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add prop-types"
  ) else if /I "%REPO%"=="core-client_pdf_publisher" (
    call :log -- temporarily adding @mui/icons-material, notistack and proskomma-json-tools...
    call :run pnpm add @mui/icons-material@6.1.5
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add @mui/icons-material@6.1.5"
    call :run pnpm add notistack
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add notistack"
    call :run pnpm add proskomma-json-tools
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add proskomma-json-tools"
  ) else if /I "%REPO%"=="core-contenthandler-print_specs" (
    call :log -- temporarily adding notistack...
    call :run pnpm add notistack
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add notistack"
  ) else if /I "%REPO%"=="core-contenthandler_translation_plan" (
    call :log -- temporarily adding @mui/icons-material and prop-types...
    call :run pnpm add @mui/icons-material@6.1.5
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add @mui/icons-material@6.1.5"
    call :run pnpm add prop-types
    if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm add prop-types"
  )

  call :log -- pnpm --config.dangerouslyAllowAllBuilds=true run build ...
  call :run pnpm --config.dangerouslyAllowAllBuilds=true run build
  if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm --config.dangerouslyAllowAllBuilds=true run build"
) else (
  call :log -- pnpm install ...
  call :run pnpm install
  if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm install"

  call :log -- pnpm run build ...
  call :run pnpm run build
  if errorlevel 1 call :markfail "CLIENT" "%REPO%" "pnpm run build"
)

call :log ################################ END Client !CLIENT_N!: %REPO% ################################
call :log
cd ..
exit /b 0


:checkout_branch
REM %~1 = type (ASSET or CLIENT), %~2 = repo name
REM Tries %BRANCH%, then each tier in %CHAIN%. Sets CHECKED_OUT_BRANCH.
call :log -- git fetch origin...
call :run git fetch origin
if errorlevel 1 call :log -- WARNING: git fetch failed; proceeding with possibly stale remote refs

call :log -- git checkout %BRANCH%...
call :run git checkout "%BRANCH%"
if not errorlevel 1 (
  set "CHECKED_OUT_BRANCH=%BRANCH%"
  exit /b 0
)

set "PREV=%BRANCH%"
for %%B in (%CHAIN%) do (
  if /I not "%%B"=="%BRANCH%" (
    set "CHECKED_OUT_BRANCH=%%B"
    call :log -- Branch "!PREV!" not found, trying "%%B"...
    call :run git checkout %%B
    if not errorlevel 1 exit /b 0
    set "PREV=%%B"
  )
)

call :markfail "%~1" "%~2" "git checkout failed for %BRANCH% and fallbacks:%CHAIN%"
exit /b 0


:safe_pull
REM %~1 = type (ASSET or CLIENT), %~2 = repo name
set "SP_TYPE=%~1"
set "SP_REPO=%~2"

if defined FRESH_CLONE (
  call :log -- Skipping pull -- -f flag set, 'fresh' clone, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "-f flag set, 'fresh' clone, no pull"
  goto :safe_pull_done
)

git diff --quiet >nul 2>&1
set "DIRTY1=!errorlevel!"
git diff --cached --quiet >nul 2>&1
set "DIRTY2=!errorlevel!"
if !DIRTY1! NEQ 0 (
  call :log -- Skipping pull -- uncommitted local changes detected on "!CHECKED_OUT_BRANCH!", no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "uncommitted local changes, no pull"
  goto :safe_pull_done
)
if !DIRTY2! NEQ 0 (
  call :log -- Skipping pull -- uncommitted local changes detected on "!CHECKED_OUT_BRANCH!", no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "uncommitted local changes, no pull"
  goto :safe_pull_done
)

git rev-parse --verify "origin/!CHECKED_OUT_BRANCH!" >nul 2>&1
if errorlevel 1 (
  call :log -- Skipping pull -- origin/!CHECKED_OUT_BRANCH! does not exist, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "origin/!CHECKED_OUT_BRANCH! does not exist, no pull"
  goto :safe_pull_done
)

set "LOCAL_AHEAD=0"
for /f %%n in ('git rev-list "origin/!CHECKED_OUT_BRANCH!..HEAD" --count 2^>nul') do set "LOCAL_AHEAD=%%n"
if !LOCAL_AHEAD! GTR 0 (
  call :log -- Skipping pull -- "!CHECKED_OUT_BRANCH!" has !LOCAL_AHEAD! unpushed commits, no pull
  call :markskip "%SP_TYPE%" "%SP_REPO%" "!CHECKED_OUT_BRANCH!" "!LOCAL_AHEAD! unpushed commits, no pull"
  goto :safe_pull_done
)

call :log -- git pull origin !CHECKED_OUT_BRANCH!...
call :run git pull origin "!CHECKED_OUT_BRANCH!"
if errorlevel 1 call :markfail "%SP_TYPE%" "%SP_REPO%" "git pull origin !CHECKED_OUT_BRANCH!"

:safe_pull_done
exit /b 0


:log
REM Echo to screen AND append the same line to %LOG% (UTF-8, no BOM)
set "LINE=%*"
if "%~1"=="" (
  echo.
  powershell -NoProfile -Command "[System.IO.File]::AppendAllText($env:LOG, [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
) else (
  echo !LINE!
  powershell -NoProfile -Command "$s=$env:LINE; [System.IO.File]::AppendAllText($env:LOG, $s + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))" >nul
)
exit /b 0


:run
REM Runs a command, shows output live, and appends the same output to %LOG%.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSRUNNER%" "%LOG%" %*
exit /b %errorlevel%


:markfail
set /a FAILCOUNT+=1
set "FAIL!FAILCOUNT!=[%~1] %~2 :: %~3"
exit /b 0


:markskip
set /a SKIPCOUNT+=1
set "SKIP!SKIPCOUNT!=[%~1] %~2 (%~3): %~4"
exit /b 0
