#!/usr/bin/env bash

# This script uses APP_VERSION as defined in app_config.json
#
# Run from pankosmia/[this-repo's-name]/macos/scripts directory:
#  ./bundle_app.sh  [tier] [-s|-S] [-p|-P]
#
# Arguments (all optional):
#   tier    One of the values in tiers.order. Defaults to tiers.default.
#   -s/-S   Skip the prompt when the server is off.
#   -p/-P indicates Portable App zip build (produces a .tgz)
#
# bundle_app.sh is a symlink to bundle_app.sh

set -e
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "     jq is required to read app_config.json."
  echo
  exit 1
fi

echo

# app_config.json at repo root
APP_CONFIG="../../app_config.json"
default_tier=$(jq -r '.tiers.default' "$APP_CONFIG")
tier_list=$(jq -r '.tiers.order | join(" ")' "$APP_CONFIG")

# get arguments
askIfOff=yes
portable=false
tier=""

while [[ "$#" -gt 0 ]]
  do case $1 in
    -[sS]) askIfOff=no
    ;;
    -[pP]) portable=true
    ;;
    *)
      if jq -e --arg t "$1" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null; then
        if [[ -n "$tier" ]]; then
          echo "" >&2
          echo "     Only one tier may be specified (got '$tier' and '$1'). One of: $tier_list" >&2
          echo "" >&2
          exit 1
        fi
        tier="$1"
      else
        serverArgs+=("$1")
      fi
      ;;
    esac
    shift
done

# Default tier is tiers.default; must still be in tiers.order
tier=${tier:-$default_tier}

if ! jq -e --arg t "$tier" '.tiers.order | index($t) != null' "$APP_CONFIG" >/dev/null; then
  echo "" >&2
  echo "     Tier \"$tier\" is not listed in tiers.order. One of: $tier_list" >&2
  echo "" >&2
  exit 1
fi

# Do not ask if the server is off if the -s argument is provided
if ! [[ $askIfOff =~ ^(-s) ]]; then
  while true; do
    read -p "Is the server off? [Y/n]: " yn
    case $yn in 
      "y" | "Y" | "" ) echo
        echo "Continuing...";
        break
        ;;
      [nN] ) echo
        echo "     Exiting...";
        echo;
        echo "     If the server is on, turn it off with Ctrl-C in the terminal window in which it is running, then re-run this script.";
        echo;
        exit
        ;;
      * ) echo
        echo "     \"$yn\" is not a valid response. Please type y or 'Enter' to continue or 'n' to quit.";
        echo
        ;;
    esac
  done
fi

# Prints the value of the single entry (in array $1) whose branches include the tier.
tier_value() {
    jq -er --arg t "$tier" --arg k "$1" \
        "[$1[] | select(.branches | index(\$t))] | if length == 1 then .[0].value else error(\$k + \" must have exactly one entry for tier \" + \$t) end" \
        "$APP_CONFIG"
}

APP_NAME=$(tier_value '.app.name') || { echo "Error: app.name not set for tier \"$tier\""; exit 1; }
APP_VERSION=$(tier_value '.app.version') || { echo "Error: app.version not set for tier \"$tier\""; exit 1; }
APP_SHORT_NAME=$(tier_value '.app.short_name') || { echo "Error: app.short_name not set for tier \"$tier\""; exit 1; }

echo
echo "Tier is $tier"
echo "Version is $APP_VERSION"
echo "App name is $APP_NAME"
echo "App short name is $APP_SHORT_NAME"
echo "Building Debian package for tier $tier..."
echo

# Full viewer install, ensuring no stale files are included.
./build_viewer.sh -f $tier

# Set variables
cd ../../
REPOPATH=$(pwd)

# Package
# - lower case
PACKAGE_NAME=${APP_NAME,,}
# - Replace spaces with a dash (-)
PACKAGE_NAME=${PACKAGE_NAME// /-}

FROM_DIR=$REPOPATH
TO_DIR=/tmp/$PACKAGE_NAME
INSTALL_DIR=$TO_DIR/opt/$PACKAGE_NAME
RELEASE_DIR=$REPOPATH/releases/linux

# Detect current CPU architecture
CPU_ARCH=$(uname -m)
if [ "$CPU_ARCH" = "x86_64" ]; then
    OUTPUT_ARCH="x64"
    DEB_ARCH="amd64"
elif [ "$CPU_ARCH" = "aarch64" ]; then
    OUTPUT_ARCH="arm64"
    DEB_ARCH="arm64"
else
    echo "Error: Unsupported CPU architecture: $CPU_ARCH"
    exit 1
fi

# Collect all components and then build it
# Create build dir if not exist
if ! [ -d $TO_DIR ]; then
    mkdir -p $INSTALL_DIR/viewer
    mkdir -p $TO_DIR/usr/bin
    mkdir -p $TO_DIR/usr/share/applications/
    mkdir -p $TO_DIR/DEBIAN
    chmod -R 755 $TO_DIR
fi

# Lib
cp -r $FROM_DIR/linux/build/lib $INSTALL_DIR
chmod 755 $INSTALL_DIR/lib
chmod 755 $INSTALL_DIR/lib/app_resources

# Bin
cp -r $FROM_DIR/linux/build/bin $INSTALL_DIR
chmod 755 $INSTALL_DIR/bin
chmod 755 $INSTALL_DIR/bin/server.bin

# Electron app
cp -r $FROM_DIR/linux/viewer/project/payload/app/electron/* $INSTALL_DIR/viewer/
chmod 755 $INSTALL_DIR/viewer/

# Alternate launcher showing Electron stdin, stdout, and stderr in the console, replacing placeholders with actual values
cp $FROM_DIR/linux/buildResources/devAppLauncherElectron.sh $INSTALL_DIR/
chmod +x $INSTALL_DIR/devAppLauncherElectron.sh

# Rocket config
cp -r $FROM_DIR/linux/viewer/project/payload/app/Rocket.toml $INSTALL_DIR/

# Icon
cp $FROM_DIR/globalBuildResources/linux_icon.png $INSTALL_DIR/$PACKAGE_NAME.png

# Copy launcher, replacing placeholders with actual values
cp $FROM_DIR/linux/buildResources/launcher.sh $TO_DIR/usr/bin/$PACKAGE_NAME
sed -i "s|{PACKAGE_NAME}|$PACKAGE_NAME|g" $TO_DIR/usr/bin/$PACKAGE_NAME
chmod +x $TO_DIR/usr/bin/$PACKAGE_NAME

# Copy desktop file, placeholders -> actual values
cp $FROM_DIR/linux/buildResources/launcher.desktop $TO_DIR/usr/share/applications/$PACKAGE_NAME.desktop
sed -i "s|{APP_NAME}|$APP_NAME|g; s|{APP_VERSION}|$APP_VERSION|g; s|{PACKAGE_NAME}|$PACKAGE_NAME|g" $TO_DIR/usr/share/applications/$PACKAGE_NAME.desktop

# Debian package description, placeholders -> actual values
cp $FROM_DIR/linux/buildResources/control $TO_DIR/DEBIAN
INSTALLED_SIZE=`du -c $TO_DIR | grep total | cut -f1`
sed -i "s|{PACKAGE_VERSION}|$APP_VERSION|g; s|{PACKAGE_NAME}|$PACKAGE_NAME|g; s|{INSTALLED_SIZE}|$INSTALLED_SIZE|g; s|{DEB_ARCH}|$DEB_ARCH|g" $TO_DIR/DEBIAN/control

# Copy preinst to DEBIAN package
cp $FROM_DIR/linux/buildResources/preinst $TO_DIR/DEBIAN
sed -i "s|{APP_SHORT_NAME}|$APP_SHORT_NAME|g" $TO_DIR/DEBIAN/preinst
sed -i "s|{PACKAGE_NAME}|$PACKAGE_NAME|g" $TO_DIR/DEBIAN/preinst
chmod +x $TO_DIR/DEBIAN/preinst

# Finally, build the package and write it to the Release directory
cd /tmp
dpkg-deb --root-owner-group --build $PACKAGE_NAME $RELEASE_DIR/$PACKAGE_NAME-$APP_VERSION-linux-$OUTPUT_ARCH.deb

# Get back into the scripts dir
cd $REPOPATH/linux/scripts

# -----------------------------------------------------------------------------
# Portable app packaging (.tgz) -- additive; runs only when -p is set.
#
# The .deb has already been built and written above, so none of the portable
# replacements below can affect it. The portable app is assembled into its own
# staged folder mirroring the .deb's $INSTALL_DIR layout, and ALL portable-
# specific edits are performed on the staged copies only -- never on
# linux/build/lib, linux/build/bin, or the viewer payload the .deb consumes.
# -----------------------------------------------------------------------------
if [ "$portable" = true ]; then
    echo "Building portable TGZ..."

    ARCH="$OUTPUT_ARCH"

    # Sources (same trees the .deb trusts; copied, never edited in place).
    PAYLOAD_SOURCE="$FROM_DIR/linux/viewer/project/payload/app"
    LIB_SOURCE="$FROM_DIR/linux/build/lib"
    BIN_SOURCE="$FROM_DIR/linux/build/bin"
    ICON_SOURCE="$FROM_DIR/globalBuildResources/linux_icon.png"

    # Portable-specific helper files.
    HELPERS_SOURCE="$FROM_DIR/linux/buildResourcesPortable"

    OUTPUT_PATH="$RELEASE_DIR"
    mkdir -p "$OUTPUT_PATH"

    PACKAGE_BASE_NAME="$PACKAGE_NAME-$APP_VERSION-linux-$OUTPUT_ARCH"

    # Stage the portable app under a top-level folder named after the app.
    PORTABLE_STAGE="$FROM_DIR/linux/viewer/project/portable-package"
    PORTABLE_APP_STAGE="$PORTABLE_STAGE/$APP_NAME"
    PORTABLE_TGZ_PATH="$OUTPUT_PATH/$PACKAGE_BASE_NAME-portable.tgz"

    if [ ! -d "$PAYLOAD_SOURCE" ]; then
        echo "Error: Portable payload directory not found: $PAYLOAD_SOURCE"
        exit 1
    fi
    if [ ! -d "$LIB_SOURCE" ]; then
        echo "Error: Portable lib source not found: $LIB_SOURCE"
        exit 1
    fi
    if [ ! -d "$BIN_SOURCE" ]; then
        echo "Error: Portable bin source not found: $BIN_SOURCE"
        exit 1
    fi

    rm -rf "$PORTABLE_STAGE"
    mkdir -p "$PORTABLE_APP_STAGE/viewer"

    # Assemble the staged app folder to mirror the .deb's $INSTALL_DIR layout.


    # Lib (staged copy -- gets the repo_dir edit below)
    cp -r "$LIB_SOURCE" "$PORTABLE_APP_STAGE/"
    chmod 755 "$PORTABLE_APP_STAGE/lib"
    chmod 755 "$PORTABLE_APP_STAGE/lib/app_resources"

    # Bin
    cp -r "$BIN_SOURCE" "$PORTABLE_APP_STAGE/"
    chmod 755 "$PORTABLE_APP_STAGE/bin"
    chmod 755 "$PORTABLE_APP_STAGE/bin/server.bin"

    # Electron app -> viewer/
    cp -r "$PAYLOAD_SOURCE/electron/"* "$PORTABLE_APP_STAGE/viewer/"
    chmod 755 "$PORTABLE_APP_STAGE/viewer/"

    # Alternate launcher showing Electron stdin, stdout, and stderr in the console, replacing placeholders with actual values
    cp $FROM_DIR/linux/buildResources/devAppLauncherElectron.sh "$PORTABLE_APP_STAGE/"
    chmod +x "$PORTABLE_APP_STAGE/devAppLauncherElectron.sh"

    # Rocket config
    cp -r "$PAYLOAD_SOURCE/Rocket.toml" "$PORTABLE_APP_STAGE/"

    # Icon
    cp "$ICON_SOURCE" "$PORTABLE_APP_STAGE/$PACKAGE_NAME.png"

    # Portable app uses a virtual path for repo_dir -- staged copy only.
    USER_SETTINGS="$PORTABLE_APP_STAGE/lib/templates/user_settings.json"
    if [ ! -f "$USER_SETTINGS" ]; then
        echo "Error: Portable user_settings.json not found: $USER_SETTINGS"
        exit 1
    fi
    sed -i 's#"repo_dir": "%%HOMEDIR%%/pankosmia_repos",#"repo_dir": "../pankosmia_repos",#' "$USER_SETTINGS"

    # Copy configured helper files to the TGZ root.
    START_APP_SH_DESTINATION="$PORTABLE_STAGE/start.sh"
    README_DESTINATION="$PORTABLE_STAGE/README.txt"

    HELPER_FILES=(
        "start.sh"
        "README.txt"
    )

    for fileName in "${HELPER_FILES[@]}"; do
        source_file="$HELPERS_SOURCE/$fileName"

        case "$fileName" in
            *)              destinationFileName="$fileName" ;;
        esac

        destination="$PORTABLE_STAGE/$destinationFileName"

        if [ ! -f "$source_file" ]; then
            echo "Error: Portable helper file not found: $source_file"
            exit 1
        fi

        cp "$source_file" "$destination"

        # Replace placeholders only in the staged TGZ copy.
        sed -i "s/%%APP_NAME%%/$APP_NAME/g" "$destination"
        sed -i "s/%%APP_SHORT_NAME%%/$APP_SHORT_NAME/g" "$destination"
        sed -i "s/%%ARCH%%/$ARCH/g" "$destination"
    done

    # Make the portable start script executable.
    chmod 755 "$START_APP_SH_DESTINATION"

    SERVER_FILE="$PORTABLE_APP_STAGE/viewer/core/server.js"
    STARTUP_FILE="$PORTABLE_APP_STAGE/viewer/electronStartup.js"

    # --- server.js ---
    SERVER_FIND="spawn(SERVER_EXECUTABLE_PATH, ["
    SERVER_REPLACE="spawn(SERVER_EXECUTABLE_PATH, ['../pankosmia/$APP_SHORT_NAME'"
    if [ ! -f "$SERVER_FILE" ]; then
        echo "Error: server.js not found: $SERVER_FILE"
        exit 1
    fi
    if grep -qF -- "$SERVER_REPLACE" "$SERVER_FILE"; then
        echo "$SERVER_FILE was not updated by this run; replacement already present."
        exit 1
    fi
    if ! grep -qF -- "$SERVER_FIND" "$SERVER_FILE"; then
        echo "Expected original text was not found in $SERVER_FILE ; no change made."
        exit 1
    fi
    sed -i "s#spawn(SERVER_EXECUTABLE_PATH, \[#spawn(SERVER_EXECUTABLE_PATH, ['../pankosmia/$APP_SHORT_NAME'#" "$SERVER_FILE"

    # --- electronStartup.js ---
    STARTUP_ANCHOR="app.setName('$APP_NAME');"
    STARTUP_INSERT="  app.setPath('userData', path.resolve(process.cwd(), '../pankosmia/AppData', '$APP_SHORT_NAME'));"
    if [ ! -f "$STARTUP_FILE" ]; then
        echo "Error: electronStartup.js not found: $STARTUP_FILE"
        exit 1
    fi
    if grep -qF -- "$STARTUP_INSERT" "$STARTUP_FILE"; then
        echo "$STARTUP_FILE was not updated by this run; setPath line already present."
        exit 1
    fi
    if ! grep -qF -- "$STARTUP_ANCHOR" "$STARTUP_FILE"; then
        echo "Expected anchor text was not found in $STARTUP_FILE ; no change made."
        exit 1
    fi
    sed -i "/app.setName('$APP_NAME');/a\\$STARTUP_INSERT" "$STARTUP_FILE"

    # Create the single-top-level-directory archive.
    rm -f "$PORTABLE_TGZ_PATH"
    tar -czf "$PORTABLE_TGZ_PATH" \
        -C "$PORTABLE_STAGE" \
        "$APP_NAME" \
        "start.sh" \
        "README.txt"

    if [ ! -f "$PORTABLE_TGZ_PATH" ]; then
        echo "Error: Portable TGZ was not created: $PORTABLE_TGZ_PATH"
        exit 1
    fi

    echo "Portable package created successfully: $PORTABLE_TGZ_PATH"
fi
