#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/windows/scripts directory in powershell by:  ./viewer.zsh
# ./build_viewer.zsh must be run once before ./viewer.zsh will work

source ../../app_config.env

echo "========================"
echo "Starting up:"
echo "Current directory:"
pwd

# Using dev server.

# Starting electronite viewer loading dev build environment
export APP_RESOURCES_DIR=../../build/lib/
../viewer/project/payload/${APP_NAME}.app/Contents/electron/Electron/Contents/MacOS/Electron ../viewer/project/payload/${APP_NAME}.app/Contents/electron
