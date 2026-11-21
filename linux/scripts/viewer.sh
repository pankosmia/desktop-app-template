#!/usr/bin/env bash

# viewer.bsh is a symlink to viewer.sh

# Run from pankosmia/[this-repo's-name]/windows/scripts directory in a terminal with:  ./viewer.sh
# ./build_viewer.sh must be run once before ./viewer.sh will work

# Currently turning off sandbox to avoid a permissions issue with Ubuntu 24.04
# One day we should do this, if necessary, within our code, just for the one viewer

export ROCKET_PORT=${1:-19119}

echo "Starting the Electronite viewer."
echo "Accessing the backend server at port ${ROCKET_PORT}."

# Using development environment server.
export START_SERVER="false"

# Starting electronite viewer, accessing the development build environment
../viewer/project/payload/app/electron/electron --no-sandbox ../viewer/project/payload/app/electron
