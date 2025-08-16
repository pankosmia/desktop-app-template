@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\clean.bat
REM Optional arguments: .\clean.bat -s
REM or: .\clean.bat -S
REM To pre-confirm the server is off, so as to not be asked.

echo.
:choice
IF "%~1"=="-s" (
  goto :server_off
) ELSE (
  set /P c=Is the server off?[Y/N y/n]?
)
if /I "%c%" EQU "Y" goto :server_off
if /I "%c%" EQU "N" goto :server_on
goto :choice


:server_on

echo.
echo      Exiting...
echo.
echo      If the server is on, turn it off by exiting the terminal window in which it is running, then re-run this script.
echo.
exit

:server_off

echo Cleaning...

if exist ..\build (
  echo Removing last build environment
  rmdir ..\build /s /q
)

if exist ..\..\local_server\target\release\local_server.exe (
    echo Cleaning local server
    cd ..\..\local_server
    cargo clean
    cd ..\windows\scripts
)

echo.
echo The local server and build environment have been cleaned.
echo.
