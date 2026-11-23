@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\build_server.bat
REM Optional arguments:
REM   -s (or -S)   Pre-confirm the server is off, so as to not be asked.
REM   -f (or -F)   Force a rebuild even if the build stamp shows the server is already built for this version.
REM   <tier>       One of tiers.order in app_config.json (e.g. dev, qa, main). Only one may be given. Default is <tiers.default>.
REM Requires: jq
REM
REM Server crate version comes from server.crate_version in app_config.json for the tier.
REM   - dev/qa/main: Cargo.toml and Cargo.lock are backed up, the crate line is rewritten, and both are restored after the build.
REM A build stamp (<server.bin>.stamp.json, e.g., /local_server/target/release/local_server.stamp.json) is written after a successful build:
REM   {"tier":"<tier>","crate":"<crate>","crate_version":"<version built>"}

setlocal

set "configFile=%~dp0..\..\app_config.json"
set "localServerDir=%~dp0..\..\local_server"
set "cargoFile=%localServerDir%\Cargo.toml"
set "cargoLock=%localServerDir%\Cargo.lock"
set "cargoBackup=%cargoFile%.bak"
set "lockBackup=%cargoLock%.bak"
set "askIfOff="
set "force="
set "tier="

where jq >nul 2>&1
if errorlevel 1 (
  echo.
  echo      jq is required to read app_config.json.
  echo.
  exit /b 1
)

REM Read tiers.order from app_config.json (space-separated list)
set "tiers="
for /f "usebackq delims=" %%T in (`jq -r ".tiers.order[]" "%configFile%"`) do call set "tiers=%%tiers%% %%T"
if not defined tiers (
  echo.
  echo      Could not read tiers.order from %configFile%
  echo.
  exit /b 1
)

REM Parse arguments: -s, -f, and one tier. Anything else is an error.
:loop
IF "%~1"=="" goto :continue

IF /I "%~1"=="-s" (
  set "askIfOff=-s"
  shift
  goto :loop
)
IF /I "%~1"=="-f" (
  set "force=1"
  shift
  goto :loop
)

set "isTier="
for %%T in (%tiers%) do if /I "%~1"=="%%T" set "isTier=%%T"

if not defined isTier (
  echo.
  echo      Unrecognized argument "%~1". Use -s, -f, and/or one tier:%tiers%
  echo.
  exit /b 1
)
if defined tier (
  echo.
  echo      Only one tier may be given ^(got "%tier%" and "%isTier%"^). One of:%tiers%
  echo.
  exit /b 1
)
set "tier=%isTier%"
shift
goto :loop

:continue

REM Default tier is <tiers.default>; must still be in tiers.order
for /f "usebackq delims=" %%T in (`jq -r ".tiers.default" "%configFile%"`) do set "DEFAULT_TIER=%%T"
if not defined tier set "tier=%DEFAULT_TIER%"
set "isTier="
for %%T in (%tiers%) do if /I "%tier%"=="%%T" set "isTier=%%T"
if not defined isTier (
  echo.
  echo      Tier "%tier%" is not listed in tiers.order. One of:%tiers%
  echo.
  exit /b 1
)

REM Server settings from app_config.json
set "crate="
for /f "usebackq delims=" %%V in (`jq -r ".server.crate // empty" "%configFile%"`) do set "crate=%%V"
if not defined crate (
  echo.
  echo      server.crate is not set in app_config.json.
  echo.
  exit /b 1
)
call :tierValue ".server.crate_version" crateVersion || exit /b 1
call :tierValue ".server.bin" serverBin || exit /b 1

REM server.bin is relative to windows\scripts (this script's dir); add .exe on Windows
set "serverBin=%serverBin:/=\%"
set "serverBase=%~dp0%serverBin%"
set "serverExe=%serverBase%.exe"
set "stampFile=%serverBase%.stamp.json"

REM Recover from an interrupted earlier run (e.g. Ctrl+C during cargo build)
if exist "%cargoBackup%" (
  echo.
  echo   WARNING: Found Cargo.toml.bak from an interrupted run. Restoring Cargo.toml and Cargo.lock first...
  call :restoreCargo
)
if exist "%lockBackup%" call :restoreCargo

set "buildVersion=%crateVersion%"

echo.
echo   Tier is %tier%
echo   Using %crate% version %crateVersion% for tier "%tier%"

REM Assign default value if -s is not present
if not defined askIfOff (
  set "askIfOff=-yes"
)

echo.
:choice
IF "%askIfOff%"=="-s" goto :server_off
set "c="
set /P "c=Is the server off? [Y/n]: "
if /I "%c%" EQU "" goto :server_off
if /I "%c%" EQU "Y" goto :server_off
if /I "%c%" EQU "N" goto :server_on
echo "%c%" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.
goto :choice

:server_on
echo.
echo      Exiting...
echo.
echo      If the server is on, turn it off by exiting the terminal window or app where it is running, then re-run this script.
echo.
exit /b 1

:server_off

REM Skip the cargo build if the stamp shows this version is already built (unless -f)
if defined force goto :build
if not exist "%serverExe%" goto :build
if not exist "%stampFile%" goto :build
set "stampVersion="
for /f "usebackq delims=" %%V in (`jq -r ".crate_version // empty" "%stampFile%"`) do set "stampVersion=%%V"
if not "%stampVersion%"=="%buildVersion%" goto :build
echo   Server is already built with %crate% %buildVersion% ^(per build stamp^). Skipping cargo build. Use -f to force a rebuild.
goto :assemble

:build
REM Remove the stamp first so a failed build never leaves a stamp describing it
if exist "%stampFile%" del "%stampFile%"

if /I not "%tier%"=="main" call :rewriteCargo

REM Build the rust server of the specified build type
echo "Building local Release server at /local_server/target/release ..."
pushd "%localServerDir%"
echo "cargo build --release"
cargo build --release
set "buildResult=%errorlevel%"
popd

REM Restore Cargo.toml and Cargo.lock if they were rewritten (success or failure)
call :restoreCargo

REM Exit if the build failed
if not "%buildResult%"=="0" (
  echo.
  echo      Build failed with exit code %buildResult%.
  echo.
  exit /b %buildResult%
)

REM Write the build stamp
>"%stampFile%" echo {"tier":"%tier%","crate":"%crate%","crate_version":"%buildVersion%"}
echo   Wrote build stamp: %crate% %buildVersion% ^(tier %tier%^)

:assemble
REM Clean the build environment
if exist ..\build (
  echo Removing last build environment
  rmdir ..\build /s /q
)

REM Assemble the build environment for the tier
if not exist ..\build (
  echo "Assembling build environment for tier %tier%..."
  node build.js %tier%
  if errorlevel 1 (
    echo.
    echo      node build.js failed for tier "%tier%".
    echo.
    exit /b 1
  )
)

exit /b 0


REM ---------------------------------------------------------------------------
REM Subroutines
REM ---------------------------------------------------------------------------

REM :tierValue <jq path to tier array> <output var>
REM Sets <output var> to the value of the single entry whose branches include %tier%.
:tierValue
set "%~2="
for /f "usebackq delims=" %%V in (`jq -r --arg t "%tier%" "[%~1[] | select(.branches | index($t))] | if length == 1 then .[0].value else empty end" "%configFile%"`) do set "%~2=%%V"
if not defined %~2 (
  echo.
  echo      %~1 must have exactly one entry for tier "%tier%" in app_config.json.
  echo.
  exit /b 1
)
exit /b 0

REM :rewriteCargo -- back up Cargo.toml and Cargo.lock, then pin %crate% to %crateVersion%
:rewriteCargo
copy /y "%cargoFile%" "%cargoBackup%" >nul
if exist "%cargoLock%" copy /y "%cargoLock%" "%lockBackup%" >nul
setlocal enabledelayedexpansion
set "cargoTmp=%cargoFile%.tmp"
(for /f "usebackq tokens=*" %%a in ("%cargoBackup%") do (
  set "line=%%a"
  echo !line! | findstr /R /C:"^%crate% *=" >nul
  if !errorlevel! equ 0 (
    echo %crate% = "=%crateVersion%"
  ) else (
    echo(!line!
  )
)) > "!cargoTmp!"
move /y "!cargoTmp!" "%cargoFile%" >nul
endlocal
exit /b 0

REM :restoreCargo -- restore Cargo.toml and Cargo.lock from backups if present
:restoreCargo
if exist "%cargoBackup%" move /y "%cargoBackup%" "%cargoFile%" >nul
if exist "%lockBackup%" move /y "%lockBackup%" "%cargoLock%" >nul
exit /b 0
