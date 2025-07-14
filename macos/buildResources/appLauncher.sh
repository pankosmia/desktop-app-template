#!/bin/sh

echo "========================"
echo "%%APP_NAME%% starting up:"
echo "Current directory:"
pwd

# find the directory path that contains this script
script_dir="$(dirname "$(realpath "$0")")"
echo "Script directory: $script_dir"

# ============================
# need to find server.bin - this is needed because working directory is not set

# first look for server.bin relative to directory script is in
if [ -e "$script_dir"/../bin/server.bin ]; then
    BASE="$script_dir/.."

# Otherwise Check for server.bin in ./bin
elif [ -e ./bin/server.bin ]; then
    BASE="."

# Otherwise Check for server.bin in ../bin
elif [ -e ../bin/server.bin ]; then
    BASE=".."

# Otherwise Check for server.bin in ./Contents/bin
elif [ -e ./Contents/bin/server.bin ]; then
    BASE="./Contents"

# finally fall back to default install path
elif [ -e /Applications/%%FILE_APP_NAME%%.app/Contents/bin/server.bin ]; then
    BASE="/Applications/%%FILE_APP_NAME%%.app/Contents"

# not found
else
    echo "Error: server.bin not found in ./bin or ../bin"
    exit 1
fi

# launch browser
URL="http://localhost:19119"
if [ -e /Applications/Firefox.app ]
then
    echo "Launching Firefox"
    open -a firefox -g "$URL" &
else
    echo "Launching Default browser"
    open "$URL" &
fi


echo "bin folder found at $BASE"
echo "Launch a web browser and enter http://localhost:19119"
echo "(Best viewed with a Graphite-enabled browser such as Firefox.)"
echo " "
cd "$BASE"
export ROCKET_PORT=19119
export APP_RESOURCES_DIR=./lib/
./bin/server.bin