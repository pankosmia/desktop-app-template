@echo off
REM Run from pankosmia\[this-repo's-name]\windows\scripts directory in powershell or command by:  .\build_server.bat
REM Git hub actions use this with optional arguments of: .\build_server.bat -c
REM because it is a brand new clean environment without need for any prior build to be removed.

IF NOT "%~1"=="-c" (
  call .\clean.bat
)
if not exist ..\..\local_server\target\release\local_server.exe (
    echo "Building local server..."
    cd ..\..\local_server
    cargo build --release
    cd ..\windows\scripts
)
if not exist ..\build (
  echo "Assembling build environment..."
  node build.js
)
