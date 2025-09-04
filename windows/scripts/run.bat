@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\run.bat
REM Optional argument: .\run.bat -s
REM To pre-confirm the server is off, so as to not be asked.

echo.
:choice
IF "%~1"=="-s" (
  goto :server_off
) ELSE (
  set /P c=Is the server off? [Y/N y/n - default is yes]: 
)
if /I "%c%" EQU "" goto :server_off
if /I "%c%" EQU "Y" goto :server_off
if /I "%c%" EQU "N" goto :server_on
echo "%c%" is not a valid response. Please enter a Y or y for yes, or an N or n for no.
goto :choice

:server_on
echo.
echo      Exiting...
echo.
echo      If the server is on, turn it off by exiting the terminal window or app where it is running, then re-run this script.
echo.
exit

:server_off

if not exist ..\..\buildSpec.json set runSetup=1
if not exist ..\..\globalBuildResources\i18nPatch.json set runSetup=1
if not exist ..\buildResources\setup\app_setup.json set runSetup=1
if defined %runSetup (
  cmd /c .\app_setup.bat
  echo.
  echo   +-----------------------------------------------------------------------------+
  echo   ^| Config files were rebuilt by `./app_setup.bsh` as one or more were missing. ^|
  echo   +-----------------------------------------------------------------------------+
  echo.
)

REM set port environment variables
set ROCKET_PORT=19119

if exist ..\build (
  echo "Removing last build environment"
  rmdir ..\build /s /q
)
if not exist ..\build (
  echo "Assembling build environment"
  node build.js
)
echo "Running..."
cd ..\build
SET APP_RESOURCES_DIR=.\lib\
start "" ".\bin\server.exe"