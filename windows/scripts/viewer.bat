REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell by:  .\viewer.bat
REM .\build_viewer.ps1 must be run once before .\viewer.bat will work

@echo off

echo ========================
echo
echo Starting electronite viewer...

REM Using dev server.

REM Starting electronite viewer loading dev build environment
set "APP_RESOURCES_DIR=..\..\build\lib\"
..\temp\project\payload\app\electron\electron.exe ..\temp\project\payload\app\electron &
