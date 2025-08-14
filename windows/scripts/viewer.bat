@echo off
setlocal enabledelayedexpansion

echo ========================
echo Starting up:
echo Current directory:
cd

REM Using dev server.

REM Start electron as background process
set "APP_RESOURCES_DIR=..\..\build\lib\"
..\temp\project\payload\app\electron\electron.exe ..\temp\project\payload\app\electron &

endlocal