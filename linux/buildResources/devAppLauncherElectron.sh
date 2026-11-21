#!/usr/bin/env bash

# This is an alternative production launcher for developer use. It shows Electron stdio in the terminal.

echo "=================================================================="
echo "Starting up with Electron stdin, stdout and stderr in the console:"
echo

# Setting variables
BASE_DIR=.
APP_DIR=$BASE_DIR
export APP_RESOURCES_DIR="$APP_DIR/lib/"

# Run everything from the app dir
cd $APP_DIR

echo "APP_RESOURCES_DIR: $APP_RESOURCES_DIR"
echo "Running everything from: $APP_DIR"
echo

START_CMD="$APP_DIR/viewer/electron --no-sandbox $APP_DIR/viewer"
printf 'Starting with: %s\n' "$START_CMD"
echo

# Start the client, which will start the server
$START_CMD
