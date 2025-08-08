@echo off
REM set port environment variables
set ROCKET_PORT=19119
set RUST_BACKTRACE=1
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