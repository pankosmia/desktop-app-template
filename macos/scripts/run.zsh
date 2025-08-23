#!/usr/bin/env zsh

# Run from pankosmia/[this-repo's-name]/macos/scripts directory by:  ./run.zsh
# with the optional arguments of: ./run.zsh -s
# to pre-specify that the server is off.

set -e
set -u

echo

# Do not ask if the server is off if the -s $1 positional argument is provided
askIfOff="${1:-yes}" # -s means "no"
if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read "choice?Only one instance of the server can be running at a time. Is the server off? [Y/N y/n]: "
    case $choice in
      [yY] ) echo
        echo "Continuing..."
        break
        ;;
      [nN] ) echo
        echo "     Exiting..."
        echo
        echo "If the server is on, turn it off (e.g., Ctrl-C in terminal window or exit app), then re-run this script."
        echo
        exit
        ;;
      * ) echo
        echo "     \"$choice\" is not a valid response. Please enter a Y or y for yes, or an N or n for no."
        echo
        ;;
    esac
  done
fi

if [ ! -f ../../buildSpec.json ] || [ ! -f ../../globalBuildResources/i18nPatch.json ] || [ ! -f ../buildResources/setup/app_setup.json ]; then
  ./app_setup.zsh
  echo
  echo "  +-----------------------------------------------------------------------------+"
  echo "  | Config files were rebuilt by \`./app_setup.zsh\` as one or more were missing. |"
  echo "  +-----------------------------------------------------------------------------+"
  echo
fi

# set port environment variables
export ROCKET_PORT=19119
export RUST_BACKTRACE=1

if [ -d ../build ]; then
  echo "Removing last build environment..."
  echo
  rm -rf ../build
fi

if [ ! -d ../build ]; then
  echo "Assembling build environment..."
  node ./build.js
fi

cd ../build

echo
echo "Running... When ready to stop this server, press Ctrl-C."
echo "       If Ctrl-Z (suspend) is used by accident, then run \`killall -9 \"server.bin\"\` or Force Quit from the Activity Monitor,"
echo "       or to resume run \`fg\` for the last suspended process, otherwise \`fg \"./run.zsh\"\`."
echo

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export APP_RESOURCES_DIR="$SCRIPT_DIR/lib/"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
$SCRIPT_DIR/bin/server.bin
