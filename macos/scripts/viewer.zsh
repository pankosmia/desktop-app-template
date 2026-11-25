#!/usr/bin/env zsh

# This script uses APP_NAME as defined in app_config.json
#
# Run from pankosmia/[this-repo's-name]/windows/scripts directory in a terminal with:  ./viewer.zsh
# ./build_viewer.zsh must be run once before ./viewer.zsh will work

export ROCKET_PORT=${1:-19119}

# app_config.json at repo root
APP_CONFIG="../../app_config.json"

# Prints the value of the single entry (in array $1) whose branches include the tier.
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

APP_NAME=$(tier_value '.app.name') || { echo "Error: app.name not set for tier \"$tier\""; exit 1; }

echo "Starting the Electronite viewer."
echo "Accessing the backend server at port ${ROCKET_PORT}."

# Using development environment server.
export START_SERVER="false"

# Starting electronite viewer, accessing the development build environment

# This bypasses ../viewer/start-*.sh (which, fyi, originates from ../buildResources/appLauncherElectron.sh)
../viewer/project/payload/${APP_NAME}.app/Contents/electron/Electron/Contents/MacOS/Electron ../viewer/project/payload/${APP_NAME}.app/Contents/electron
