@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\run.bat
REM Optional arguments:
REM   -s (or -S)       Pre-confirm the server is off, so as to not be asked.
REM   <tier>           One of tiers.order in app_config.json (e.g. dev, qa, main). Only one may be given.
REM                    Default is dev. Passed to `node build.js`.
REM   All other arguments are forwarded to server.exe.
REM Requires: jq

setlocal

set "configFile=%~dp0..\..\app_config.json"
set "serverArgs="
set "askIfOff="
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

REM Parse arguments: -s, one tier, everything else forwarded to server.exe
:loop
IF "%~1"=="" goto :continue

IF /I "%~1"=="-s" (
  set "askIfOff=-s"
  shift
  goto :loop
)

set "isTier="
for %%T in (%tiers%) do if /I "%~1"=="%%T" set "isTier=%%T"

if defined isTier (
  if defined tier (
    echo.
    echo      Only one tier may be given ^(got "%tier%" and "%isTier%"^). One of:%tiers%
    echo.
    exit /b 1
  )
  set "tier=%isTier%"
) ELSE (
  set "serverArgs=%serverArgs% %1"
)

shift
goto :loop

:continue

REM Default tier is dev (most common for local runs); must still be in tiers.order
if not defined tier set "tier=dev"
set "isTier="
for %%T in (%tiers%) do if /I "%tier%"=="%%T" set "isTier=%%T"
if not defined isTier (
  echo.
  echo      Tier "%tier%" is not listed in tiers.order. One of:%tiers%
  echo.
  exit /b 1
)

REM Assign default value if -s is not present
if not defined askIfOff (
  set "askIfOff=-yes"
)

if not exist ..\..\local_server\target\release\local_server.exe (
  echo.
  echo      Exiting...
  echo.
  echo      The local server does not exist. Run `.\build_server.bat`, then re-run this script.
  echo.
  exit /b 1
)

echo.
echo Tier is %tier%

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

REM set available port environment variable (returned as %ROCKET_PORT% )
call ..\buildResources\find_free_port.bat
echo Serving on port %ROCKET_PORT%...

if exist ..\build (
  echo Removing last build environment...
  rmdir ..\build /s /q
)
if not exist ..\build (
  echo Assembling build environment for tier %tier%...
  node build.js %tier%
  if errorlevel 1 (
    echo.
    echo      node build.js failed for tier "%tier%".
    echo.
    exit /b 1
  )
)
echo Running with local server in release mode...
cd ..\build
SET "APP_RESOURCES_DIR=.\lib\"
start "" cmd /k ".\bin\server.exe%serverArgs%"
